%% @author Simon Peter Campbell (n3053620)
%% @copyright 2015 Simon Peter Campbell
%% @version 1.0

%% @doc
%% The tcp module provides basic TCP handling functionality to the server.
%% To start a tcp listener simply call spawn_handler, this will spawn a PID which will be returned.
%% To close a tcp listener just send it the 'shutdown' atom.
-module (tcp).

-include ("server.hrl").

-export ([spawn_handler/1]).


%% @doc
%% Spawns a TCP listener which will handle incoming connections and messages on the given port.
%% @spec spawn_handler (Port) -> pid()
%%       Port = integer()
spawn_handler (Port) when is_integer (Port) ->

    %% Return a spawned listener at the given port.
    spawn (fun() -> listener (Port) end).



%% @doc
%% Creates a listening socket on the given port and waits to receive connections. The port can be closed by sending
%% the shutdown command to its associated PID.
%% @spec listener (Port) -> none()
%%       Port = integer()
listener (Port) ->

    %% Start by trying to create a socket.
    case gen_tcp:listen (Port, ?TCP_SETTINGS) of

        %% Await connections and wait for the shutdown command.
        {ok, Socket} ->
            io:format ("TCP: Starting TCP listener on port ~p.~n", [Port]),

            Handler = self(),
            spawn (fun() -> accept (Handler, Socket) end),

            %% Close all connections.
            Sockets = handle_messages ([Socket]),
            lists:foreach (fun (Sock) -> gen_tcp:close (Sock) end, Sockets);

        %% Log the reason for failure.
        {error, Reason} ->
            io:format ("TCP: Unable to create a listener on port ~p: ~p~n", [Port, Reason])

    end.



%% @doc
%% Enters a receive loop until given the shutdown command.
%% @spec handle_messages (Sockets) -> [socket()]
%%       Sockets = [socket()]
handle_messages (Sockets) ->

    receive

        %% Add the connection to the current list.
        {connected, Socket} ->
            handle_messages (lists:append (Sockets, [Socket]));

        %% Remove the connection from the current list.
        {disconnected, Socket} ->
            handle_messages (lists:delete (Socket, Sockets));

        %% Forward any packets to the desired sockets.
        {send, Socket, Packet} ->
            spawn (fun() -> send_packet (Socket, Packet) end),
            handle_messages (Sockets);

        %% Exit gracefully.
        shutdown ->
            io:format ("TCP: Shutting down.~n")

    after

        %% Time out if necessary.
        ?TIMEOUT ->
            io:format ("TCP: Timed out.~n")

    end,

    %% Return the list.
    Sockets.



%% @doc
%% Accepts all incoming TCP connections until the given socket is closed.
%% @spec accept (Handler, Socket) -> none()
%%       Handler = pid()
%%       Socket = socket()
accept (Handler, Socket) ->

    %% Loop until the socket is closed.
    case gen_tcp:accept (Socket) of

        %% Retrieve packets from the new connection and inform the handler of the connection.
        {ok, Connection} ->
            io:format ("TCP: Client has connected.~n"),
            spawn (fun() -> receive_packets (Handler, Connection) end),
            Handler ! {connected, Connection},
            accept (Handler, Socket);

        %% Exit gracefully.
        {error, closed} ->
            io:format ("TCP: Stopped accepting connections.~n");

        %% Output the strange failure.
        {error, Reason} ->
            io:format ("TCP: Unable to accept a connection on socket ~p, ~p~n", [Socket, Reason])

    end,

    %% Inform the handler of the disconnected socket.
    Handler ! {disconnected, Socket}.



%% @doc
%% Receives packets from the desired connection and forwards messages to the message handler.
%% @spec receive_packets (Handler, Connection) -> none()
%%       Handler = pid()
%%       Connection = socket()
receive_packets (Handler, Connection) ->

    %% Wait to receive packets from the connected client.
    case gen_tcp:recv (Connection, 0, ?TIMEOUT) of

        %% Handle the message elsewhere.
        {ok, Packet} ->
            message_handler:process (tcp, Handler, Connection, Packet),
            receive_packets (Handler, Connection);

        %% Exit gracefully.
        {error, closed} ->
            io:format ("TCP: Client closed connection.~n");

        %% Output the strange failure.
        {error, Reason} ->
            io:format ("TCP: Unable to receive a packet from connection ~p, ~p~n", [Connection, Reason])

    end,

    %% Remove the connection from the handler.
    Handler ! {disconnected, Connection}.



%% @doc
%% Sends a packet to the desired socket.
%% @spec send_packet (Socket, Packet) -> ok
%%       Socket = socket()
%%       Packet = string() | binary() | term()
send_packet (Socket, Packet) ->

    case gen_tcp:send (Socket, [Packet, 0]) of

        %% Output errors.
        {error, Reason} ->
            io:format ("TCP: Unable to send packet on socket ~p, ~p.~n", [Socket, Reason]);

        %% Do nothing.
        _ ->
            ok
    end.