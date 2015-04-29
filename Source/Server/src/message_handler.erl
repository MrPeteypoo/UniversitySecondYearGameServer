%% @author Simon Peter Campbell (n3053620)
%% @copyright 2015 Simon Peter Campbell
%% @version 1.0

%% @doc
%% This module handles the processing of messages which have been received via TCP or UDP.
-module (message_handler).

-include ("server.hrl").

-export ([process/4]).


%% @doc
%% Creates a new linked process which will handle the message given. The responder and connection variables are used
%% to create a reply function so that the sender can receive a response.
%% @spec process (Protocol, Responder, Connection, Message) -> pid()
%%       Protocol = tcp | udp
%%       Responder = pid()
%%       Connection = socket() | inet:ip_address() | inet:hostname()
%%       Message = string() | binary()
process (Protocol, Responder, Connection, Message) ->

    %% We need to give the handler a means of replying.
    Reply = fun (Packet) -> Responder ! {send, Connection, Packet} end,

    %% Spawn a new handler.
    spawn (fun() -> handle (Protocol, Connection, Message, Reply) end).



%% @doc
%% Handles all messages supported by the server.
%% @spec handle (Protocol, Connection, Message, Reply) -> any()
%%       Protocol = tcp | udp
%%       Connection = socket() | {inet:ip_address() | inet:hostname(), inet:port_number()}
%%       Message = string() | binary()
%%       Reply = function()
handle (Protocol, Connection, Message, Reply) ->

    %% Best handle those messages bro!
    case Message of

        %% Broadcast messages.
        <<"I'm not your friend, buddy!", _/binary>> ->
            handle_broadcast (Reply);

        %% Register dat peep.
        <<"connect:", IsMaster:8,  Name/binary>> ->
            add_client (Protocol, Name, IsMaster, Connection, Reply);

        %% We need to be careful about disconnecting clients.
        <<"disconnect:", Name/binary>> ->
            remove_client (Protocol, Name, Connection);

        %% Positions are stored as two 32 bit values.
        <<"update_position:", X:32, Y:32, Name/binary>> ->
            update (update_position, Name, {X, Y});

        %% Scores are stored with 32 bits.
        <<"update_score:", Score:32, Name/binary>> ->
            update (update_score, Name, Score);

        %% Send stored position and score values back to the client.
        <<"synchronise:", _/binary>> ->
            synchronise (Reply);

        %% Allow messages to be sent only to the master.
        <<"send_master:", Packet/binary>> ->
            send_master (Protocol, Connection, Packet);

        %% Allow messages to be sent only to the slaves.
        <<"send_slaves:", Packet/binary>> ->
            send_slaves (Protocol, Connection, Packet);

        %% Or allow messages to be sent to everyone.
        <<"send_all:", Packet/binary>> ->
            send_all (Protocol, Connection, Packet);

        %% Output unknown messages.
        _ ->
            io:format ("Message Handler: Unknown message received, ~p.~n", [Message])

    end.



%% @doc
%% Handles broadcast messages to the server.
%% @spec handle_broadcast (Reply) -> any()
%%       Reply = function()
handle_broadcast (Reply) ->

    %% Construct a simple message to say hello.
    Reply (<<"I'm not your buddy, guy!\n">>).



%% @doc
%% Registers a client with the server if it isn't full, if the client exists then it attempts to update the TCP or
%% UDP information of the client.
%% @spec add_client (Mode, Client, IsMaster, Connection, Reply) -> any()
%%       Mode = tcp | udp
%%       Client = string()
%%       IsMaster = byte()
%%       Connection = socket() | {inet:ip_address() | inet:hostname(), inet:port_number()}
%%       Reply = function()
add_client (Mode, Client, IsMaster, Connection, Reply) ->

    %% We need to know if the client exists because if so then we are simply updating TCP or UDP information.
    case clients:exists (Client) of

        %% Update the clients TCP or UDP information.
        true ->
            update (Mode, Client, Connection),
            Reply (<<"accepted:">>);

        %% Test if we can add the client.
        false ->
            case clients:count() of

                ?MAX_CLIENTS ->
                    Reply (<<"refused:">>);

                _FreeSlot ->
                    update (Mode, Client, Connection),

                    %% Reply informing the client it has connected but have a separate process send a message to all in
                    %% case the client doesn't get added to the client list in time.
                    Reply (<<"connect_success:">>),
                    spawn (fun() -> send_all (Mode, Connection, [<<"connected:">>, Client]) end)
            end

    end,

    %% Only set the client to master if one doesn't exist.
    case clients:master() of

        none ->
            update (update_master, Client, IsMaster);

        _ ->
            ok
    end.



%% @doc
%% Attempts to remove a client from the server. This command can only be sent by the registered client, the request
%% will be declined otherwise.
%% @spec remove_client (Protocol, Client, Connection) -> any()
%%       Protocol = tcp | udp
%%       Client = string()
%%       Connection = TCP | UDP
%%       Reply = function()
%%       TCP = socket()
%%       UDP = {inet:ip_address() | inet:hostname(), inet:port_number()}
remove_client (Protocol, Client, Connection) ->

    %% The TCP or UDP information must be valid for the client to be removed.
    case validation:check_connection (Client, Connection) of

        %% Remove and all clients.
        true ->
            send_all (Protocol, Connection, [<<"removed:">>, Client]),
            clients:manager() ! {remove_client, Client};

        %% We don't like cheaters!
        false ->
            io:format ("Message Handler: Attempt was made to disconnect client '~p' from '~p'.~n", [Client, Connection])

    end.



%% @doc
%% Updates the field of a client with the given values.
%% @spec update (Mode, Client, Values) -> any()
%%       Mode = tcp | udp | update_position | update_score | update_master
%%       Client = string()
%%       Values = term() | {term()}
update (Mode, Client, Values) ->

    %% Tell the clients manager to update some values.
    clients:manager() ! {Mode, Client, Values}.



%% @doc
%% Sends a message directly to the master client.
%% @spec send_master (Protocol, Connection, Message) -> any()
%%       Protocol = tcp | udp
%%       Connection = socket() | {inet:ip_address() | ip:hostname(), inet:port_number()}
%%       Message = binary()
send_master (Protocol, Connection, Message) ->

    Send = fun() -> send (Protocol, Message, clients:master()) end,
    validation:client_action (Connection, Send).



%% @doc
%% Sends a message directly to the slave clients.
%% @spec send_slaves (Protocol, Connection, Message) -> any()
%%       Protocol = tcp | udp
%%       Connection = socket() | {inet:ip_address() | ip:hostname(), inet:port_number()}
%%       Message = binary()
send_slaves (Protocol, Connection, Message) ->

    Send = fun (Client) -> send (Protocol, Message, Client) end,
    Action = fun() -> lists:foreach (Send, clients:slaves()) end,
    validation:client_action (Connection, Action).



%% @doc
%% Sends a message to all clients.
%% @spec send_all (Protocol, Connection, Message) -> any()
%%       Protocol = tcp | udp
%%       Connection = socket() | {inet:ip_address() | ip:hostname(), inet:port_number()}
%%       Message = binary()
send_all (Protocol, Connection, Message) ->

    Send = fun (Client) -> send (Protocol, Message, Client) end,
    Action = fun() -> lists:foreach (Send, clients:all()) end,
    validation:client_action (Connection, Action).



%% @doc
%% Sends a message via TCP or UDP to the given client.
%% @spec send (Protocol, Message, Client) -> ok
%%       Protocol = tcp | udp
%%       Message = binary
%%       Client = {Key, TCP, IP, Port, X, Y, Score, Master}
%%       TCP = socket()
%%       IP = inet:ip_address() | inet:hostname()
%%       Port = inet:port_number()
send (Protocol, Message, {_, TCP, IP, Port, _, _, _, _}) ->

    case Protocol of

        tcp ->
            whereis (?TCP) ! {send, TCP, Message};

        udp ->
            whereis (?UDP) ! {send, {IP, Port}, Message}

    end.



%% @doc
%% Sends the requesting client the current position and score values of each client.
%% @spec synchronise (Reply) -> ok
%%       Reply = function()
synchronise (Reply) ->

    SyncMessage = fun ({Name, _, _, _, X, Y, Score, _}) -> Reply ([<<"sync:">>, X, Y, Score, Name]) end,
    lists:foreach (SyncMessage, clients:all()).