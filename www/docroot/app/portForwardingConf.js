angular.module('fw').constant('PortForwardingConf', {

    consoles_codes: {start: 1,      end: 50},           // rules with code between  1 and  50 are reserved to consoles
    services_codes: {start: 51,     end: 999},          // rules with code between 51 and 999 are reserved to services

    consoles: [
        {
            name: 'Xbox Live',
            code: '1',
            rules: [
                { port_start: 88,   port_end: 88,       proto: 'UDP' },
                { port_start: 500,  port_end: 500,      proto: 'UDP' },
                { port_start: 3544, port_end: 3544,     proto: 'UDP' },
                { port_start: 4500, port_end: 4500,     proto: 'UDP' },
                { port_start: 3074, port_end: 3074,     proto: 'TCP' },
                { port_start: 3074, port_end: 3074,     proto: 'UDP' },
                { port_start: 53,   port_end: 53,       proto: 'TCP' },
                { port_start: 53,   port_end: 53,       proto: 'UDP' },
                { port_start: 80,   port_end: 80,       proto: 'TCP' }
            ]
        },
        {
            name: 'Playstation Network',
            code: '2',
            rules: [
                { port_start: 3478,   port_end: 3478,       proto: 'UDP' },
                { port_start: 3479,   port_end: 3479,       proto: 'UDP' },
                { port_start: 3658,   port_end: 3658,       proto: 'UDP' },
                { port_start: 10070,  port_end: 10070,      proto: 'UDP' },
                { port_start: 80,     port_end: 80,         proto: 'TCP' },
                { port_start: 443,    port_end: 443,        proto: 'TCP' },
                { port_start: 5223,   port_end: 5223,       proto: 'TCP' }
            ]
        }
    ],

    services: [
        {
            name: 'AIM Talk',
            code: '51',
            rules: [
                { port_start: 5190,   port_end: 5190,   proto: 'TCP' }
            ]
        },
        {
            name: 'Bit Torrent',
            code: '52',
            rules: [
                { port_start: 6881,   port_end: 6889,   proto: 'TCP' }
            ]
        },
        {
            name: 'BearShare',
            code: '53',
            rules: [
                { port_start: 6346,   port_end: 6346,   proto: 'TCP' }
            ]
        },
        {
            name: 'Checkpoint FW1 VPN',
            code: '54',
            rules: [
                { port_start: 2599,   port_end: 2599,   proto: 'TCP' },
                { port_start: 2599,   port_end: 2599,   proto: 'UDP' }
            ]
        },
        {
            name: 'Counter Strike',
            code: '55',
            rules: [
                { port_start: 1200,   port_end: 1200,   proto: 'UDP' },
                { port_start: 27000,  port_end: 27015,  proto: 'UDP' },
                { port_start: 27030,  port_end: 27030,  proto: 'TCP' }
            ]
        },
        {
            name: 'DirectX 7',
            code: '56',
            rules: [
                { port_start: 2302,   port_end: 2400,   proto: 'UDP' },
                { port_start: 47624,  port_end: 47624,  proto: 'UDP' }
            ]
        },
        {
            name: 'DirectX 8',
            code: '57',
            rules: [
                { port_start: 2302,   port_end: 2400,   proto: 'UDP' },
                { port_start: 6073,   port_end: 6073,   proto: 'UDP' }
            ]
        },
        {
            name: 'DirectX 9',
            code: '58',
            rules: [
                { port_start: 2302,   port_end: 2400,   proto: 'UDP' },
                { port_start: 6073,   port_end: 6073,   proto: 'UDP' }
            ]
        },
        {
            name: 'eMule',
            code: '59',
            rules: [
                { port_start: 4662,   port_end: 4662,   proto: 'TCP' },
                { port_start: 4672,   port_end: 4672,   proto: 'TCP' }
            ]
        },
        {
            name: 'FTP Server',
            code: '60',
            rules: [
                { port_start: 21,   port_end: 21,   proto: 'TCP' }
            ]
        },
        {
            name: 'Gamespy Arcade',
            code: '61',
            rules: [
                { port_start: 6500,   port_end: 6500,   proto: 'UDP' },
                { port_start: 6700,   port_end: 6700,   proto: 'UDP' },
                { port_start: 12300,  port_end: 12300,  proto: 'UDP' },
                { port_start: 27900,  port_end: 27900,  proto: 'UDP' },
                { port_start: 28900,  port_end: 28900,  proto: 'TCP' },
                { port_start: 23000,  port_end: 23009,  proto: 'UDP' }
            ]
        },
        {
            name: 'HTTP Server (World Wide Web)',
            code: '62',
            rules: [
                { port_start: 8080,   port_end: 8080,   proto: 'TCP' }
            ]
        },
        {
            name: 'HTTPS Server',
            code: '63',
            rules: [
                { port_start: 443,   port_end: 443,   proto: 'TCP' }
            ]
        },
        {
            name: 'iMesh',
            code: '64',
            rules: [
                { port_start: 1214,   port_end: 1214,   proto: 'TCP' }
            ]
        },
        {
            name: 'KaZaA',
            code: '65',
            rules: [
                { port_start: 1214,   port_end: 1214,   proto: 'TCP' }
            ]
        },
        {
            name: 'Mail Server (SMTP)',
            code: '66',
            rules: [
                { port_start: 25,   port_end: 25,   proto: 'TCP' },
                { port_start: 25,   port_end: 25,   proto: 'UDP' }
            ]
        },
        {
            name: 'Microsoft Remote Desktop',
            code: '67',
            rules: [
                { port_start: 3389,   port_end: 3389,   proto: 'TCP' },
                { port_start: 3389,   port_end: 3389,   proto: 'UDP' }
            ]
        },
        {
            name: 'MSN Game Zone',
            code: '68',
            rules: [
                { port_start: 6667,   port_end: 6667,   proto: 'TCP' },
                { port_start: 6667,   port_end: 6667,   proto: 'UDP' },
                { port_start: 28800,  port_end: 29000,  proto: 'TCP' },
                { port_start: 28800,  port_end: 29000,  proto: 'UDP' }
            ]
        },
        {
            name: 'MSN Game Zone (DX)',
            code: '69',
            rules: [
                { port_start: 2300,   port_end: 2400,   proto: 'TCP' },
                { port_start: 2300,   port_end: 2400,   proto: 'UDP' },
                { port_start: 47624,  port_end: 47624,  proto: 'TCP' },
                { port_start: 47624,  port_end: 47624,  proto: 'UDP' }
            ]
        },
        {
            name: 'NNTP Server',
            code: '70',
            rules: [
                { port_start: 119,   port_end: 119,   proto: 'TCP' },
                { port_start: 119,   port_end: 119,   proto: 'UDP' },
                { port_start: 1723,  port_end: 1723,  proto: 'TCP' }
            ]
        },
        {
            name: 'Secure Shell Server (SSH)',
            code: '71',
            rules: [
                { port_start: 22,   port_end: 22,   proto: 'TCP' }
            ]
        },
        {
            name: 'Steam Games',
            code: '72',
            rules: [
                { port_start: 27030,   port_end: 27039,   proto: 'TCP' },
                { port_start: 1200,    port_end: 1200,    proto: 'UDP' },
                { port_start: 27000,   port_end: 27015,   proto: 'UDP' }
            ]
        },
        {
            name: 'Telnet Server',
            code: '73',
            rules: [
                { port_start: 23,   port_end: 23,   proto: 'TCP' }
            ]
        },
        {
            name: 'VNC',
            code: '74',
            rules: [
                { port_start: 5500,   port_end: 5500,   proto: 'TCP' },
                { port_start: 5500,   port_end: 5500,   proto: 'UDP' },
                { port_start: 5800,   port_end: 5800,   proto: 'TCP' },
                { port_start: 5800,   port_end: 5800,   proto: 'UDP' },
                { port_start: 5900,   port_end: 5900,   proto: 'UDP' }
            ]
        }
    ]
});
