{
    application, flaky_snakey_server,
    [
        {vsn, "1.0"},
        {modules, [flaky_snakey_server, tcp, udp, message_handler, clients, validation]},
        {registered, [flaky_snakey_server]},
        {mod, {flaky_snakey_server, []}}
    ]
}.
