%% @author Simon Peter Campbell (n3053620)
%% @copyright 2015 Simon Peter Campbell
%% @version 1.0

%% @doc
%% This module provides functionality to validate a connection of a client against the client list.
%% Certain functions will also perform an action upon validating a connection.
-module (validation).

-include ("server.hrl").

-export ([check_connection/2, client_action/2]).


%% @doc
%% Checks if the TCP or UDP configuration given matches those stored in the ETS.
%% @spec check_connection (Name, TCP | UDP) -> boolean()
%%       Name = string()
%%       TCP = socket()
%%       UDP = {IP, Port}
%%       IP = inet:ip_address() | inet:hostname()
%%       Port = inet:port_number()
check_connection (Name, Socket) when not is_tuple (Socket) ->

    case clients:client (Name) of

        %% We only need to check the the IP and Port values.
        {_, StoredSocket, _, _, _, _, _, _} ->
            Socket =:= StoredSocket;

        %% If it doesn't exist then we're fine to ignore it.
        none ->
            false

    end;



%% Checks if the TCP or UDP configuration given matches those stored in the ETS.
check_connection (Name, {IP, Port}) ->

    case clients:client (Name) of

        %% We only need to check the the IP and Port values.
        {_, _, StoredIP, StoredPort, _, _, _, _} ->
            (IP =:= StoredIP) and (Port =:= StoredPort);

        %% If it doesn't exist then we're fine to ignore it.
        none ->
            false

    end.



%% @doc
%% Calls the given action provided the TCP or UDP information given is associated with a connected client.
%% @spec client_action (TCP | UDP, Action) -> any()
%%       TCP = socket()
%%       UDP = {IP, Port}
%%       IP = inet:ip_address() | ip:hostname()
%%       Port = inet:port_number()
%%       Action = function()
client_action (Socket, Action) when not is_tuple (Socket) ->

    %% We need to check the TCP socket of a client.
    Predicate = [{{'$1', '$2', '$3', '$4', '$5', '$6', '$7', '$8'},
                  [{'=:=', '$2', Socket}],
                  ['$_']}],

    check_action (Predicate, Action);



%% Calls the given action provided the TCP or UDP information given is associated with a connected client.
client_action ({IP, Port}, Action) ->

    %% We need to check the IP and port of the client.
    Predicate = [{{'$1', '$2', '$3', '$4', '$5', '$6', '$7', '$8'},
                  [{'=:=', '$3', IP}, {'=:=', '$4', Port}],
                  ['$_']}],

    check_action (Predicate, Action).



%% @doc
%% Checks if the ETS select function returns a match, if so the action will be performed.
%% @spec check_action (Predicate, Action) -> any()
%%       Predicate = term()
%%       Action = function()
check_action (Predicate, Action) ->

    case ets:select (?CLIENTS, Predicate) of

        %% Only perform the action if the socket is linked with a client.
        [] ->
            io:format ("Validation: Attempt to perform an action from an invalid client.~n");

        _ ->
            Action()

    end.