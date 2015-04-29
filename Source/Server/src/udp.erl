%% @author Simon Peter Campbell (n3053620)
%% @copyright 2015 Simon Peter Campbell
%% @version 1.0

%% @doc
%% The udp module provides basic UDP handling functionality to the server.
%% To start a UDP listener call the spawn_handler function. This will return the PID of a UDP listener.
%% To close a UDP listener send the process the 'shutdown' command.
-module (udp).

-include ("server.hrl").

-export ([spawn_handler/1]).


%% @doc
%% Spawns a UDP listener which will receive packets on the desired port.
%% @spec spawn_handler (Port) -> pid()
%%       Port = integer()
spawn_handler (Port) when is_integer (Port) ->

    %% Return a spawned listener at the given port.
    spawn (fun() -> listener (Port) end).



%% @doc
%% Opens a UDP socket on the desired socket and wait to receive packets.
%% @spec listener (Port) -> none()
%%       Port = integer()
listener (Port) ->

    %% Start by trying to create a socket.
    case gen_udp:open (Port, ?UDP_SETTINGS) of

        %% Await connections and wait for the shutdown command.
        {ok, Socket} ->
            io:format ("UDP: Starting UDP listener on port ~p.~n", [Port]),

            Handler = self(),
            spawn (fun() -> receive_packets (Handler, Socket) end),

            %% Close the connection when we're finished.
            handle_messages (Socket),
            gen_udp:close (Socket);

        %% Log the reason for failure.
        {error, Reason} ->
            io:format ("UDP: Unable to create a listener on port ~p: ~p~n", [Port, Reason])

    end.



%% @doc
%% Enters a receive loop until given the shutdown command.
%% @spec handle_messages (Socket) -> socket()
%%       Socket = socket()
handle_messages (Socket) ->

    receive

        %% Forward any packets to the desired address.
        {send, {Address, Port}, Packet} ->
            spawn (fun() -> send_packet (Socket, Address, Port, Packet) end),
            handle_messages (Socket);

        %% Exit gracefully.
        shutdown ->
            io:format ("UDP: Shutting down.~n")

    after

        %% Time out if necessary.
        ?TIMEOUT ->
            io:format ("UDP: Timed out.~n")

    end.



%% @doc
%% Receives packets from the desired socket and forwards messages to the message handler.
%% @spec receive_packets (Handler, Socket) -> none()
%%       Handler = pid()
%%       Socket = socket()
receive_packets (Handler, Socket) ->

    %% Wait to receive packets from the connected client.
    case gen_udp:recv (Socket, 0, ?TIMEOUT) of

        %% Handle the message elsewhere.
        {ok, {Address, Port, Packet}} ->
            message_handler:process (udp, Handler, {Address, Port}, Packet),
            receive_packets (Handler, Socket);

        %% Exit gracefully.
        {error, closed} ->
            io:format ("UDP: Port closed.~n");

        %% Output the strange failure.
        {error, Reason} ->
            io:format ("UDP: Unable to receive a packet from socket ~p, ~p~n", [Socket, Reason])

    end.



%% @doc
%% Sends a packet to the desired address.
%% @spec send_packet (Socket, Address, Port, Packet) -> ok
%%       Socket = socket()
%%       Address = inet:ip_address() | inet:hostname()
%%       Port = inet:port_number()
%%       Packet = iodata()
send_packet (Socket, Address, Port, Packet) ->

    case gen_udp:send (Socket, Address, Port, [Packet, 0]) of

        %% Output any errors.
        {error, Reason} ->
            io:format ("UDP: Unable to send packet on socket '~p' to address '~p', ~p", [Socket, Address, Reason]);

        %% We need not do anything.
        _ ->
            ok

    end.