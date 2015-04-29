%% @author Simon Peter Campbell (n3053620)
%% @copyright 2015 Simon Peter Campbell
%% @version 1.0

%% @doc
%% This module provides an entry point to the application. The server can be started as an application
%% or using the start/2 function. A maximum of four player snakes are possible.
-module     (flaky_snakey_server).
-behaviour  (application).

-include    ("server.hrl").

-export     ([start/2, stop/1]).


%% @doc
%% Starts the server, ready for processing incoming connections. The Port variable will be refused
%% unless it is an integer.
%% @spec start (atom(), Port) -> none()
%%       Port = integer()
start (_, Port) ->

    if
        %% Ensure the port is valid.
        is_integer (Port) ->
            io:format ("Starting server on port ~p.~n", [Port]),
            server (Port);

        %% Exit due to invalid parameters.
        true ->
            io:format ("Invalid port given to server.~n"),
            exit (invalid_port)
    end.



%% @doc
%% Stops the server from running, closing all connections and killing all processes.
%% @spec stop (Reason) -> true
%%       Reason = term()
stop (Reason) ->

    io:format ("Shutting down the server with argument: ~p.~n", [Reason]),
    exit (whereis (?SERVER), shutdown).



%% @doc
%% Starts the server on the given port.
%% @spec server (Port) -> none()
%%       Port = integer()
server (Port) ->

    %% Spawn the necessary systems and wait to receive messages.
    register (?SERVER, self()),

    Clients = clients:manager(),
    TCP     = tcp:spawn_handler (Port),
    UDP     = udp:spawn_handler (Port),

    register (?TCP, TCP),
    register (?UDP, UDP),

    handle_messages(),

    %% Clean up after ourselves.
    Clients ! shutdown,
    TCP     ! shutdown,
    UDP     ! shutdown.



%% @doc
%% Handles all messages sent to the server.
%% @spec handle_messages() -> none()
handle_messages() ->

    receive

        %% Exit gracefully.
        shutdown ->
            io:format ("Server: Shutting down.~n");

        %% Log unrecognised messages.
        Unknown ->
            io:format ("Server: Received unknown message: ~p~n", [Unknown]),
            handle_messages()

    end.