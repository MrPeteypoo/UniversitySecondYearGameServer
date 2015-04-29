%% @author Simon Peter Campbell (n3053620)
%% @copyright 2015 Simon Peter Campbell
%% @version 1.0

%% @doc
%% The clients module provides encapsulation of an ETS which stores information on each connected client application.
%% All writing operations must be performed by sending a message to the ?CLIENTS pid, however, read operations can be
%% performed by simply calling a function from this module.
-module (clients).

-include ("server.hrl").

-export ([manager/0, client/1, all/0, master/0, slaves/0, has_master/0, exists/1, count/0]).


%% @doc
%% Spawns a manager for the clients ETS or obtains the existing one. Only this PID can perform write operations.
%% @spec manager() -> pid()
manager() ->

    %% Only allow one manager per application.
    Result = whereis (?CLIENTS),

    if
        is_pid (Result) ->
            Result;

        true ->
            io:format ("Clients Manager: Creating ETS.~n"),
            spawn (fun() -> create() end)
    end.



%% @doc
%% Obtains the information for a client with the given name.
%% @spec client (Name) -> {Key, TCP, IP, UDP, X, Y, Score, Master} | none
%%       Key = string()
%%       TCP = socket()
%%       IP = inet:ip_address() | inet:hostname()
%%       UDP = inet:port_number()
%%       X = float()
%%       Y = float()
%%       Score = integer()
%%       Master = byte()
client (Name) ->

    %% Use the loopup function for efficiency.
    Accessor = fun (Pred) -> ets:lookup (?CLIENTS, Pred) end,

    accessor (Accessor, Name).



%% @doc
%% Obtains all clients.
%% @spec all() -> [Client] | none
%%       Client = {Key, TCP, IP, UDP, X, Y, Score, Master}
%%       Key = string()
%%       TCP = socket()
%%       IP = inet:ip_address() | inet:hostname()
%%       UDP = inet:port_number()
%%       X = float()
%%       Y = float()
%%       Score = integer()
%%       Master = byte()
all() ->

    %% Select all zee clients!
    Accessor = fun (Pred) -> ets:select (?CLIENTS, Pred) end,
    Predicate = [{{'$1', '$2', '$3', '$4', '$5', '$6', '$7', '$8'}, [], ['$_']}],

    multiple (Accessor, Predicate).



%% @doc
%% Obtains the master client.
%% @spec master() -> {Key, TCP, IP, UDP, X, Y, Score, Master} | none
%%       Key = string()
%%       TCP = socket()
%%       IP = inet:ip_address() | inet:hostname()
%%       UDP = inet:port_number()
%%       X = float()
%%       Y = float()
%%       Score = integer()
%%       Master = byte()
master() ->

    %% We need to check if any master value is higher than zero. Master is the eighth column.
    Accessor = fun (Pred) -> ets:select (?CLIENTS, Pred) end,
    Predicate = [{{'$1', '$2', '$3', '$4', '$5', '$6', '$7', '$8'},
                  [{'/=', '$8', 0}],
                  ['$_']}],

    accessor (Accessor, Predicate).



%% @doc
%% Obtains all slave clients.
%% @spec slaves() -> [Client] | none
%%       Client = {Key, TCP, IP, UDP, X, Y, Score, Master}
%%       Key = string()
%%       TCP = socket()
%%       IP = inet:ip_address() | inet:hostname()
%%       UDP = inet:port_number()
%%       X = float()
%%       Y = float()
%%       Score = integer()
%%       Master = byte()
slaves() ->

    %% We need to check for master values of zero.
    Accessor = fun (Pred) -> ets:select (?CLIENTS, Pred) end,
    Predicate = [{{'$1', '$2', '$3', '$4', '$5', '$6', '$7', '$8'},
                  [{'==', '$8', 0}],
                  ['$_']}],

    multiple (Accessor, Predicate).



%% @doc
%% Checks if a client is in master mode or not.
%% @spec has_master() -> boolean()
has_master() ->

    %% We need to check if master() returns none.
    master() =:= none.



%% @doc
%% Checks if a client with the given name already exists.
%% @spec exists (Name) -> boolean()
%%       Name = string()
exists (Name) ->

    %% Take advantage of the member function.
    ets:member (?CLIENTS, Name).



%% @doc
%% Returns the number of connected clients.
%% @spec count() -> integer() | undefined
count() ->

    %% The ETS will provide us with valuable info.
    ets:info (?CLIENTS, size).



%% @doc
%% Accesses an ETS with the given function using the given predicate.
%% @spec accessor (AccessETS, Predicate) -> Client | none
%%       AccessETS = function()
%%       Predicate = term()
%%       Client = tuple()
accessor (AccessETS, Predicate) ->

    case AccessETS (Predicate) of

        %% Indicate failure by returning none.
        [] ->
            none;

        %% Return the client.
        [Client] ->
            Client

    end.



%% @doc
%% Access the ETS in a way that will provide a list of results, instead of a single result.
%% @spec multiple (AccessETS, Predicate) -> [Client] | none
%%       AccessETS = function()
%%       Predicate = term()
%%       Client = tuple()
multiple (AccessETS, Predicate) ->

    case AccessETS (Predicate) of

        %% An empty list represents nothing.
        []  ->
            none;

        %% Return the entire string.
        Clients ->
            Clients

    end.



%% @doc
%% Creates an ETS to store client information then awaits messages.
%% @spec create() -> none()
create() ->

    %% Register ourself and create the ETS.
    register (?CLIENTS, self()),
    ets:new (?CLIENTS, ?CLIENTS_SETTINGS),
    manage().


%% @doc
%% Awaits incoming write operations to perform on the clients ETS.
%% @spec manage() -> none()
manage() ->

    %% Output the number of connected clients.
    io:format ("Clients Manager: Connected clients == ~p.~n", [count()]),

    receive

        %% Add a client via TCP.
        {tcp, Name, Socket} ->
            add_update_client (Name, tcp, fun() -> update_tcp (Name, Socket) end),
            manage();

        %% Add a client via UDP.
        {udp, Name, {Address, Port}} ->
            add_update_client (Name, udp, fun() -> update_udp (Name, Address, Port) end),
            manage();

        %% Remove a client.
        {remove_client, Name} ->
            remove_client (Name),
            manage();

        %% We need those X and Y values bruv.
        {update_position, Name, {X, Y}} ->
            update_position (Name, X, Y),
            manage();

        %% Only update the score value.
        {update_score, Name, Score} ->
            update_score (Name, Score),
            manage();

        %% Only one can be zee master!
        {update_master, Name, IsMaster} ->
            update_master (Name, IsMaster),
            manage();

        %% Exit gracefully.
        shutdown ->
            io:format ("Clients Manager: Shutting down.~n"),
            ets:delete_all_objects (?CLIENTS);

        %% Log invalid messages.
        Invalid ->
            io:format ("Clients Manager: Invalid message received, ~p.~n", [Invalid]),
            manage()

    end.



%% @doc
%% Updates the TCP or UDP information of a client, if the client doesn't exist then it registers them first.
%% @spec add_update_client (Name, Protocol, Function) -> ok
%%       Name = string()
%%       Protocol = tcp | udp
%%       Function = function()
add_update_client (Name, Protocol, Function) ->

    %% We need to check if we should add or update a current client.
    case client (Name) of

        %% Insert a new client.
        none ->
            io:format ("Clients Manager: Inserting client '~p'.~n", [Name]),
            ets:insert (?CLIENTS, {Name, tcp, ip, udp, 0, 0, 0, 0}),
            Function();

        %% Don't allow TCP information to be overwritten.
        {_, tcp, _, _, _, _, _, _} when Protocol =:= tcp ->
            Function();

        %% Don't allow UDP information to be overwritten.
        {_, _, ip, udp, _, _, _, _} when Protocol =:= udp ->
            Function();

        _ ->
            io:format ("Clients Manager: Attempt to modify ~p properties of client '~p'.~n", [Protocol, Name])

    end.



%% @doc
%% Removes a client from the ETS.
%% @spec remove_client (Name) -> true
%%       Name = string()
remove_client (Name) ->

    %% Delete it from the ETS.
    ets:delete (?CLIENTS, Name),
    io:format ("Clients Manager: '~p' successfully removed.~n", [Name]).



%% @doc
%% Updates the TCP socket associated with a client.
%% @spec update_tcp (Name, Socket) -> ok
%%       Name = string()
%%       Socket = socket()
update_tcp (Name, Socket) ->

    %% Only update the socket.
    Pos = 2,
    update_client (Name, [{Pos, Socket}]).



%% @doc
%% Updates the UDP IP associated with a client.
%% @spec update_udp (Name,IP, Port) -> ok
%%       Name = string()
%%       IP = inet:ip_address() | inet:hostname()
%%       Port = inet:port_number()
update_udp (Name, IP, Port) ->

    %% Only update the UDP socket and IP.
    PosIP = 3,
    PosPort = 4,
    update_client (Name, [{PosIP, IP}, {PosPort, Port}]).



%% @doc
%% Updates the X and Y values stored for a client.
%% @spec update_position (Name, X, Y) -> ok
%%       Name = string()
%%       X = float()
%%       Y = float()
update_position (Name, X, Y) ->

    %% Only update the X and Y values.
    PosX = 5,
    PosY = 6,
    update_client (Name, [{PosX, X}, {PosY, Y}]).



%% @doc
%% Updates the score value stored for a client.
%% @spec update_score (Name, Score) -> ok
%%       Name = string()
%%       Score = integer()
update_score (Name, Score) ->

    %% Only update the score value.
    Pos = 7,
    update_client (Name, [{Pos, Score}]).



%% @doc
%% Updates the master mode of the client.
%% @spec update_master (Name, Master) -> ok
%%       Name = string()
%%       Master = byte()
update_master (Name, Master) ->

    %% Only update the master value.
    Pos = 8,
    update_client (Name, [{Pos, Master}]).



%% @doc
%% Updates a client with the position and value pairs found in Values.
%% @spec update_client (Name, Values) -> ok
%%       Name = string()
%%       Values = [{Position, Value}]
%%       Position = integer()
%%       Value = term()
update_client (Name, Values) ->

    %% Obtain the current data for the given client.
    case ets:update_element (?CLIENTS, Name, Values) of

        %% Output the programmers silliness.
        false ->
            io:format ("Clients Manager: Attempt to update invalid client '~p'.~n", [Name]);

        %% We worked! Yay!
        _ ->
            ok

    end.