angular.module('fw')
    .constant('INTL_IT', {
        LANG: 'ita',
        LANG_L: 'Change language',
        SUBNAV : {
            HOME: 'home',
            WIFI: 'wifi',
            LINE: 'connessione',
            DEVICES: 'dispositivi',
            ADVANCED: 'avanzate',
            MODEM: 'modem',
            INFO: 'informazioni',
            VOICE: 'telefono',
						ONT: 'ont',
            CHANGE_PASSWORD: 'Cambia password',
            SUPPORT: 'ASSISTENZA'
        },
        AUTH: {
            APPLY: 'Applica',
            CHANGE_PASSWORD: 'CAMBIA PASSWORD',
            FIRSTLOGIN: 'PRIMO LOGIN',
            YOURETHEFIRST: 'Stai facendo il login per la prima volta.<br>Imposta username e password.',
            LOGIN: 'LOGIN',
            REMEMBER_ME: 'Resta connesso',
            ERRORS: {
                WRONG_CREDENTIALS: 'Lo username o la password inseriti non sono corretti',
                PASSWORD_MISSMATCH: 'La password di verifica non coincide',
                CHANGEPASSWORDERR: 'Qualcosa è andato storto, prova dinuovo'
            }
        },
        FOOTER: {
            SUGGESTIONS: 'Suggerimenti'
        },
        WEEK: {SUN: 'DOM', SAT: 'SAB', FRI: 'VEN', THU: 'GIO', WED: 'MER', TUE: 'MAR', MON: 'LUN'},
        LOADER: 'Caricamento in corso...',
        FORMS: {
            SAVE_CHANGES: 'Salva modifiche',
            CANCEL: 'Annulla',
            CLOSE: 'Chiudi',
            DELETE: 'Elimina', // Standard delete column name
            NAME: 'Nome', // Standard name column name
            STATUS: 'Stato', // Standard status column name
            ENABLED: 'Attiva',
            DISABLED: 'Disattiva',
            CONNECTED: 'Connesso',
            DISCONNECTED: 'Disconnesso',
            ADD: 'Aggiungi',
            REMOVE: 'Rimuovi',
            FROM_TIME: 'dalle',
            TO_TIME: 'alle',
            ON_TIME: 'alle',
            RANGE_FROM: 'da',
            RANGE_TO: 'a',
            REQUIRED: 'Errore: Campi invalidi'
        },
        DEV_ICONS: {
            ICON0: 'Console',
            ICON1: 'Stampante',
            ICON2: 'Computer',
            ICON3: 'Laptop',
            ICON4: 'Cellulare',
            ICON5: 'Tablet',
            ICON6: 'TV',
            ICON7: 'Altro',
            ICON8: 'Hard disk'
        },
        WIDGETS: {
            LINE_STATUS: {
                TITLE: 'LINEA (velocità di allineamento)',
                TITLE_SHORT: 'LINEA',
                RANGE: {
                    TITLE: 'Intervallo',
                    DAY: 'Giorno',
                    WEEK: 'Settimana',
                    MONTH: 'Mese'
                },
                AVERAGE_UP: 'media upload',
                AVERAGE_DOWN: 'media download',
                AVERAGE_day: 'Velocità media giornaliera',
                AVERAGE_week: 'Velocità media settimanale',
                NEW_LINE : 'Effettua una nuova verifica ora',
                IP_ADDRESS: 'Indirizzo IP',
                UPLOAD_M: 'UPLOAD <sub>velocità media</sub>',
                DOWNLOAD_M: 'DOWNLOAD <sub>velocità media</sub>'
            },
            DEVICES: {
                TITLE: 'DISPOSITIVI ONLINE',
                TITLE_SHORT: 'DISPOSITIVI ONLINE',
                FAMILY: 'dispositivi in <br />famiglia',
                FAMILY_M: 'IN FAMIGLIA <sub>dispositivi online</sub>',
                OTHERS: 'altri <br />dispositivi',
                OTHERS_M: 'ALTRI <sub>dispositivi online</sub>',
                ONLINE_NOW: 'dispositivi online <br/> connessi alla rete principale',
                CIRCLES: 'Cerchie:',
                FILTER:{
                    TITLE: 'Visualizza',
                    STATE: 'Stato',
                    BOOST: 'Boost',
                    STOP: 'Stop'
                }    
            },
            LED_STATUS: {
                TITLE: 'SPIE LED',
                TITLE_SHORT: 'SPIE LED',
                LEGEND: {
                    PRESENCE: { TITLE: 'Luce di presenza', TITLE_M: 'Luce di <br />presenza', ON: 'Accesa', OFF: 'Spenta', ALTON: 'Ok', ALTOFF: 'Problema' },
                    LINE: { TITLE: 'Stato linea', TITLE_M: 'Linea', ON: 'Presente', OFF: 'Assente', NAN: '--', ALTON: 'Ok', ALTOFF: 'Problema' },
                    WIFI: { TITLE: 'Stato Wifi', TITLE_M: 'Wifi', ON: 'Acceso', OFF: 'Spento', NAN: '--', ALTON: 'Ok', ALTOFF: 'Problema' },
                    WPS: { TITLE: 'WPS', TITLE_M: 'WPS', ON: 'Acceso', OFF: 'Spento', NAN: '--', CON: 'In abbinamento', ALTON: 'Ok', ALTOFF: 'Problema' }
                },
                WARNING: 'ATTENZIONE!',
                WARNING_MSG: 'È stato riscontrato un problema nel tuo sistema',
                ALLRIGHT: 'OTTIMO!',
                ALLRIGHT_MSG: 'Nessun problema è stato riscontrato nel tuo sistema',
                WIFI_OFF: 'La tua rete principale è attualmente disattiva. Per riattivare accedi alla sezione <a class="link" href="#/wifi" ui-sref="wifi">wifi</a>',
                UPDATE: 'Aggiorna stato LED'
            },
            WIFI_CHANNEL: {
                TITLE: 'CANALE WIFI',
                TITLE_SHORT: 'CANALE WIFI',
                NETWORKS_SHORT: 'reti', 
                RESCAN_CHANNEL: 'Canale WiFi nuova scansione',
                WIFI_CH: 'Canale wifi attualmente sintonizzato:',
                CHANNELS: 'canali',
                FILTER: {
                    TITLE: 'Gestisci',
                    FREQ2_4: 'Rete principale (2,4 GHz)',
                    FREQ2_4_M: 'Rete 2,4 GHz',
                    FREQ5: 'Rete principale (5 GHz)',
                    FREQ5_M: 'Rete 5 GHz'
                },
                BUSY: 'Questo canale è alquanto occupato! Sintonizza la rete su altri canali per migliori prestazioni.'
            },
            PARENTAL_CONTROL: {
                TITLE: 'PARENTAL CONTROL',
                TITLE_SHORT: 'PARENTAL CONTROL',
                PROTECTED_DEVS: 'dispositivi <br />protetti',
                ENABLED_ALL_NETWORK: 'Parental Control <br />attivo su tutta la rete.',
                ENABLED_ALL_DEVICES: 'Tutti i dispositivi sono protetti.',
                DISABLED_ALL_NETWORK: 'Parental Control <br />non attivo.',
                DISABLED_ALL_DEVICES: 'Nessun dispositivo protetto.',
                ADD: 'Aggiungi dispositivo',
                REMOVE: 'Rimuovi dispositivo',
                MODAL_TITLE_ADD: 'Aggiungi dispositivo al Parental Control',          
                MODAL_TITLE_REMOVE: 'Rimuovi dispositivo dal Parental Control',
                MODAL_SEARCH_MODE_AUTO: 'Dispositivi online',
                MODAL_SEARCH_MODE_MANUAL: 'Aggiunta manuale',
                SHOW_DETAILS: 'Vedi dettaglio'   
            },
            FAMILY_DEVICES: {
                TITLE: 'DISPOSITIVI IN FAMIGLIA',
                ONLINE: 'dispositivi <br />online',
                OFFLINE: 'dispositivi <br />offline',
                ADD: 'Aggiungi dispositivo',
                REMOVE: 'Rimuovi dispositivo',
                MODAL_TITLE_ADD: 'Aggiungi dispositivo alla famiglia',  
                MODAL_SEARCH_MODE: 'Metodo di ricerca',
                MODAL_SEARCH_MODE_ONLINE: 'Dispositivi online',
                MODAL_SEARCH_MODE_OFFLINE: 'Dispositivi offline',
                MODAL_SEARCH_NO_RESULT: 'Nessun dispositivo disponibile.',
                MODAL_DEVICE_LIST: 'Lista dispositivi',
                MODAL_DEVICE_NAME: 'Nome dispositivo',
                MODAL_ADD_MAC_ADDRESS: 'Inserisci MAC address',
                MODAL_TITLE_REMOVE: 'Rimuovi dispositivo dalla famiglia',
                ACTIVE_ROUTINES: 'Ci sono {{routines_num}} routine attualmente attive: ',
                ACTIVE_ROUTINES_AND: ' e ',
                BOOST_ON: 'Boost su ',
                STOP_ON: 'Stop su '
            }
        },
        PENDING_CHANGES: {
            TITLE: 'ATTENZIONE!',
            MESSAGE: 'Hai effettuato alcune modifiche <br />che non sono state salvate.',
            NOTES: 'Se esci da questa sezione le tue modifiche non verranno salvate.',
            BTN_CONFIRM: 'Procedi'
        },
        ERROR_OPERATION: {
            TITLE: 'Errore',
            MESSAGE: '<p>Si è verificato un errore durante l\'esecuzione dell\'operazione richiesta.</p>'+
                     '<p>Verifica di essere connesso alla rete e prova a ricaricare la pagina.</p>'+
                     '<p>Se il problema persiste, contatta l\' assistenza clienti</p>',
            CLOSE: 'Chiudi'
        },
        PAGES: {
            WIFI: {
                MAIN_NETWORK: {
                    TITLE: 'RETE PRINCIPALE (2,4 GHz E 5 GHz)',
                    TITLE_SHORT: 'RETE PRINCIPALE',
                    SSID_NETWORK_NAME: 'Nome Rete (SSID)',
                    SSID_BROADCAST: 'Broadcast SSID',
                    WIFI_SECURITY_TYPE: 'Protezione',
                    PASSWORD: 'Password',
                    PASSWORD_SECURITY_LABEL: 'Livello di sicurezza della tua password:',
                    PASSWORD_SECURITY: {
                        NONE: '--',
                        LOW: 'Basso',
                        MEDIUM: 'Medio',
                        HIGH: 'Alto',
                        VERY_HIGH: 'Molto alto'
                    },
                    PASSWORD_GENERATE_NOW: 'Genera una nuova password ora',
                    WPS_DESCRIPTION: 'Il WPS permette di stabilire in modo semplice e rapido una connessione internet tra il tuo FASTGate e un dispositivo Wi-Fi che si vuole accoppiare alla tua rete {{ssid_value}}. <br />'
                        +'. Premi il tasto sul tuo FASTGate, finché il LED inizierà a lampeggiare. <br />'+
                            'Entro 120 secondi, premi il tasto WPS anche sul dispositivo che vuoi accoppiare. <br />'+
                            "Al termine dell'operazione una luce verde fissa ti notificherà l'avvenuta connessione. <br />"+
                            'La presenza di luce rossa fissa indica invece che la connessione non è riuscita: ripeti la procedura descritta oppure configura il tuo dispositivo utilizzando le credenziali WiFi riportate sopra.',
                    ACTIVATE_WPS_NOW: 'Attiva WPS ora',
                    ACTIVATE_WPS_DESCRIPTION: 'E\' possibile attivare la funzionalità WPS non solo fisicamente - premendo il tasto sul tuo Fastgate, come descritto sopra - ma anche via software, attraverso il pulsante "Attiva WPS ora".',
                    AUTO_SHUTDOWN: 'Spegnimento automatico',
                    AUTO_SHUTDOWN_DESCRIPTION: 'Per tutta la durata impostata non potrai utilizzare questa rete. Allo scadere del timer la rete si riattiva automaticamente.',
                    ACTIVE: 'Attivo',
                    INACTIVE: 'Disattivo',
                    WILL_SHUT_IN: 'WiFi si spegnerà tra',
                    DURATION: 'Durata',
                    RADIUS_AUTHENTICATION_IPADDR: 'RADIUS Authentication Server IP',
                    RADIUS_AUTHENTICATION_PORT: 'RADIUS Authentication Server Port',
                    RADIUS_AUTHENTICATION_KEY: 'RADIUS Authentication Server key',
                    RADIUS_ACCOUNTING_IPADDR: 'RADIUS Accounting Server IP',
                    RADIUS_ACCOUNTING_PORT: 'RADIUS Accounting Server Port',
                    RADIUS_ACCOUNTING_KEY: 'RADIUS Accounting Server key'
                },
                GUEST_NETWORK: {
                    TITLE: 'RETE OSPITI',
                    TITLE_SHORT: 'RETE OSPITI',
                    PASSWORD_WILL_BE_REGENERATED: 'Questa password verrà rigenerata in modo automatico ogni volta che attiverai la rete ospite o in seguito ad una tua richiesta.',
                    SHOW_QR_CODE: 'Visualizza QR Code',
                    RESTRICTIONS: 'Restrizioni navigazione',
                    MAX_TIME: 'Tempo massimo',
                    NO_MAX_TIME: 'Nessuno',
                    DEVICES_WILL_BE_DISCONNECTED: 'I dispositivi connessi a questa rete verranno automaticamente dissociati dalla rete allo scadere del tempo massimo impostato',
                    FILTERING: 'Consenti',
                    FILTERING_ALL: 'Tutti i servizi',
                    FILTERING_WEB: 'Solo navigazione',
                    TIME_LEFT: 'restanti'
                },
                MAIN_NETWORK_SHARED: {
                    ENABLED: 'Attiva',
                    DISABLED: 'Disattiva',
                    DIVIDE_BY_BANDWIDTH: 'Dividi rete per banda',
                    DIVIDE_BY_BAND_DESCRIPTION: "Dividere le reti in base alla banda ti permette di scegliere come trasmettere i dati via wifi, semplicemente selezionando la rete con l'estensione SSID desiderata.",
                    
                    ACTIVE_5GHZ: 'Rete 5 GHz attiva',
                    NAME_5GHZ: 'Nome Rete 5 GHz (SSID)',
                    SECURITY_5GHZ: 'Protezione rete 5 GHz',
                    PASSWORD_5GHZ: 'Password rete 5 GHz',
                    
                    ACTIVE_2_4GHZ: 'Rete 2,4 GHz attiva',
                    NAME_2_4GHZ: 'Nome Rete 2,4 GHz (SSID)',
                    SECURITY_2_4GHZ: 'Protezione rete 2,4 GHz',
                    PASSWORD_2_4GHZ: 'Password rete 2,4 GHz'
                },
                ECO_RANGES: {
                    NONE: 'Non ripetere',
                    WEEK_END: 'Fine settimana',
                    WEEKDAYS: 'Feriali',
                    ALL: 'Tutti i giorni'
                },
                AUTH_TYPES: {
                    NONE: 'Aperta',
                    NONE_DESCR: 'Nessuna protezione (impostazione sconsigliata)',
                    WEP: 'WEP',
                    WEP_DESCR: 'A causa di importanti falle nei meccanismi di protezione, i metodi di crittografia WEP e WPA TKIP sono considerati inefficienti e pertanto vengono sconsigliati. Queste modalità devono essere utilizzate solo se necessario per supportare dispositivi Wi-Fi legacy non compatibili con WPA2 AES né aggiornabili a questa modalità. I dispositivi che si servono di questi metodi di crittografia poco efficienti non potranno trarre i massimi vantaggi dalle prestazioni 802.11n e da altre funzioni.',
                    WPA2PSK: 'WPA2-PSK',
                    WPA2PSK_DESCR:'WPA2 implementa gli elementi opzionali dello standard IEEE 802.11i. In particolare introduce un nuovo algoritmo basato su AES, CCMP, che è considerato completamente sicuro.',
                    WPAWPA2PSK: 'WPA-PSK + WPA2-PSK',
                    WPAWPA2PSK_DESCR:'WPA2 implementa gli elementi opzionali dello standard IEEE 802.11i. In particolare introduce un nuovo algoritmo basato su AES, CCMP, che è considerato completamente sicuro.',
                    
                    WPA2ENT: 'WPA2 Enterprise',
                    WPA2ENT_DESCR:'WPA2 implementa gli elementi opzionali dello standard IEEE 802.11i. In particolare introduce un nuovo algoritmo basato su AES, CCMP, che è considerato completamente sicuro.',
                    WPAWPA2ENT: 'WPA+WPA2 Enterprise',
                    WPAWPA2ENT_DESCR:'WPA2 implementa gli elementi opzionali dello standard IEEE 802.11i. In particolare introduce un nuovo algoritmo basato su AES, CCMP, che è considerato completamente sicuro.'
                },
                MODAL_WPS: {
                    TITLE_0: 'Tentativo di associazione in corso...',
                    TITLE_1: 'Associazione riuscita!',
                    TITLE_2: 'Nessun dispositivo rilevato',
                    REMAINING: 'secondi rimanenti',
                    STATUS_SUCCESS: 'Un dispositivo si è associato alla tua rete principale ed è attualmente online.<br/><br/>Accedi alla sezione <a ui-sref="devices" ng-click="ctrl.cancel()" href="#devices">Dispositivi Online</a> per gestire.',
                    STATUS_FAILED: 'Nessun dispositivo si è associato alla tua rete entro il tempo prestabilito.',
                },
                MODAL_WIFI_DISABLED: {
                    TITLE: 'ATTENZIONE!',
                    MESSAGE: 'Sei proprio sicuro di voler disattivare il wifi <br />della rete principale?',
                    NOTES: 'Ricordati che una volta spento dovrai collegarti con cavo ethernet via PC per poterlo riaccendere <br />'+
                        'oppure premere il tasto <span class="ico-wps"></span> WPS sul tuo FASTGate.<br />' +
                        'Una volta attivato il wifi, tutte le impostazioni verranno ripristinate e non perderai nessun <br />'+
                        'settaggio (nome rete, password, spegnimento automatico...).',
                    BTN_CONFIRM: 'Spegni wifi'
                },
                MODAL_WIFI_RESTART: {
                    TITLE: 'ATTENZIONE!',
                    WAIT: 'ATTENDERE...',
                    MESSAGE: "Questa operazione potrebbe richiedere fino ad un minuto <br />e disconnettere temporaneamente i tuoi dispositivi dalla rete.",
                    NOTES: 'Una volta applicate le nuove impostazioni potresti non navigare in wifi: <br />ricorda di riconnetterti alla rete prima di procedere.',
                    RECONFIGURING: 'Riconfigurazione della rete in corso...',
                    BTN_CONFIRM: 'Procedi'
                }
            },
            INFO: {
                TECH_INFO: {
                    TITLE: 'SCHEDA TECNICA',
                    SUPPLIER_NAME: 'Nome fornitore',
                    PRODUCT_NAME: 'Nome prodotto',
                    SW_VERSION: 'Versione software',
                    FW_VERSION: 'Versione firmware',
                    LAN_UPTIME: 'Modem Uptime',
                    HW_VERSION: 'Versione hardware',
                    GW_IP: 'IP del gateway',
                    MAC_ADDR: 'Indirizzo MAC WAN'
                },
                LEGAL_NOTICES: {
                    TITLE: 'NOTE LEGALI'
                },
                ACTIONS: {
                    RESTART: 'Riavvia Fastgate'
                }
            },
            LINE: {
                LINE_STATUS: {
                    TITLE: 'LINEA',
                    EDIT: { 
                        VERIFY: 'Verifica automatica',
                        VERIFY_MAN: 'Verifica manuale',
                        FREQ: 'Frequenza',
                        FREQ_1: 'Ogni giorno',
                        FREQ_6: 'Sei volte al giorno',
                        FREQ_INFO:'Tutte le verifiche eseguite vengono salvate nello storico. </br>Attenzione! Il numero di misure salvabili è limitata, maggiore è la frequenza con cui esegui le verifiche, minore è il tempo in cui esse rimarranno in memoria nello storico.',
                        TABLE:{
                            TITLE: 'Dettaglio Storico',
                            ALL: 'Tutti',
                            MAX: 'Picchi max.',
                            MIN: 'Picchi min.',
                            DATE: 'Data'
                        }

                    }
                },
                WIFI_CHANNEL: {
                    TITLE: 'CANALE WIFI',
                    SEARCH_CHANNEL: 'Ricerca automatica<br>canale migliore',
                    SEARCH_CHANNEL_DESC_2G: 'La ricerca automatica del canale wifi migliore ti permette di posizionarti in una delle tre frequenze che non si accavallano con altre - ovvero scegliendo tra i canali 1, 6 o 11 - in base al disturbo (RSSI) di eventuali altre reti vicino a te.',
                    SEARCH_CHANNEL_DESC_5G: 'La ricerca automatica ti permette di posizionarti sul canale wifi migliore in base al disturbo di eventuali altre reti vicino a te.',
                    CHANNEL: 'Canale attuale',
                    CHANNEL_DESC: 'Se vuoi sintornizzare il canale wifi autonomamente, basati sull\'evidenza del grafico e sul disturbo (RSSI) di eventuali altre reti vicino a te grazie alle informazioni nei dettagli. <br/>Ricorda che solitamente ogni rete potrebbe influenzare l\'efficienza dei due canali alla sua destra e alla sua sinistra.',
                    HZ_CHANNEL: 'Ampiezza canale',
                    CHANNEL_BUSY: 'The current channet is pretty busy! Tune your network in to other channels for better performance!',
                    EDIT:{
                        TABLE:{
                            TITLE: 'Dettagli',
                            CHANNEL: 'Canale',
                            NAME: 'Nome rete (SSID)',
                            MAC : 'Indirizzo MAC (BSSID)',
                            RSSI: 'RSSI'
                        }
                    }
                }
            },
            DEVICES: {
                ONLINE: {
                    TITLE: 'DISPOSITIVI ONLINE',
                    TITLE_M: 'ONLINE',
                    DEVICE: 'Dispositivo',
                    CIRCLE: 'Cerchia',
                    ACTIVE_BOOSTS: '1 boost attivo ora: {{boost_remaining}}\' rimanenti',
                    ACTIVE_STOPS: '1 stop attivo ora: {{stop_remaining}}\' rimanenti',
                    FAM_DEVICES_LINK_P1: 'Accedi a ',
                    FAM_DEVICES_LINK_P2: 'Dispositivi in Famiglia',
                    FAM_DEVICES_LINK_P3: ' per gestire routine.',
                    DURATION: 'Durata modalit&agrave;',
                    IN_FAMILY: 'in Famiglia',
                    OTHER: 'Altro'
                },
                FAMILY_DEVICES: {
                    TITLE: 'DISPOSITIVI IN FAMIGLIA',
                    TITLE_M: 'IN FAMIGLIA',
                    TABLE : {
                        TITLE : 'Dettagli',
                        DEVICES: 'Dispositivi',
                        STATUS: 'Stato',
                        MODE: 'Modalit&agrave;'    
                    },
                    EDIT: {
                        NAME: 'Nome',
                        ICON: 'Icona',
                        STATUS: 'Stato',
                        LAST_CONNECTION: 'Ultima connessione effettuata il ',
                        CONNECTION: 'Connesso via',
                        CONNECTION0: 'Ethernet',
                        CONNECTION1: 'Wifi',
                        CONNECTION_WIFI: 'Connesso su rete ',
                        ROUTINE: 'Routine',
                        BOOST: 'Boost',
                        BOOST_STATUS: 'programmato',
                        BOOST_AT: 'alle',
                        BOOST_SCHEDULER: 'Durata',
                        STOP: 'Stop',
                        CONTROLLER: 'Parental Control',
                        WEEKEND: 'Fine settimana',
                        WORKING: 'Feriali',
                        EVERYDAY: 'Tutti i giorni',
                        INFO: 'Per configurare manualmente le restrizioni passa alla sezione <a  ui-sref="advanced" href="#/advanced">Avanzate</a>'
                    }
                },
                OTHERS: {
                    TITLE: 'ALTRI DISPOSITIVI',
                    TABLE : {
                        TITLE : 'Dettagli',
                        DEVICES: 'Dispositivi',
                        STATUS: 'Stato',
                        MODE: 'Modalit&agrave;',
                        LAST_CONNECTION: 'Ultima connessione'
                    }
                }
            },
            ADVANCED: {
                PARENTAL: {
                    TITLE: 'PARENTAL CONTROL',
                    PC_ACTIVE: 'Parental control attualmente attivo su {{dev_num}} dispositivi.',
                    PC_INACTIVE: 'Parental control attualmente disattivato.',
                    PC_ALL: 'Parental control attualmente attivo su tutta la rete.',
                    ADD_NEW: 'Aggiungi URL',
                    MODAL_ADD_URL_TITLE: 'Aggiungi URL da bloccare',
                    FORM: {
                        APPLY_TO: {
                            TITLE: 'Applica a',
                            SINGLE: 'Singoli dispositivi',
                            ALL: 'Tutta la rete',
                            DESCRIPTION: 'Applicando il parental control ai singoli dispositivi, potrai gestire le restrizioni in modo specifico per ciascuno dei tuoi apparati, anche accedendo alla sezione <a href="#/devices">Dispositivi</a>'
                        },
                        BLOCKS: {
                            TITLE: 'Lista blocchi'
                        }
                    },
                    PROTECTED_DEVICES: 'DISPOSITIVI PROTETTI'
                },
                RESTRICTIONS: {
                    TITLE: 'RESTRIZIONE ACCESSI',
                    ADD_NEW: 'Aggiungi dispositivo',
                    MODAL_TITLE_ADD: 'Aggiungi dispositivo alla lista',  
                    MODAL_SEARCH_MODE: 'Metodo di ricerca',
                    MODAL_SEARCH_MODE_AUTO: 'Dispositivi online',
                    MODAL_SEARCH_MODE_MANUAL: 'Aggiunta manuale',
                    MODAL_DEVICE_LIST: 'Lista dispositivi',
                    MODAL_DEVICE_NAME: 'Nome dispositivo',
                    MODAL_ADD_MAC_ADDRESS: 'MAC address',                  
                    BEHAVIOUR: {
                        TITLE: 'Comportamento',
                        ALLOW: 'Consenti accesso',
                        DENY: 'Nega accesso',
                        DESCRIPTION: 'Consentendo l\'accesso alla lista dei dispositivi qui sotto, tutti i dispositivi non presenti in lista non avranno accesso al tuo Fastgate.'
                    },
                    LIST: {
                        TITLE: 'Lista dispositivi',
                        MAC: 'Indirizzo MAC'
                    }
                },
                PORT_CONF_EASY: {
                    TITLE: 'CONFIGURAZIONE SEMPLIFICATA PORTE',
                    TITLE_MOBILE: 'CONFIGURAZIONI',
                    UPNP: 'UPnP',
                    UPNP_DESC: "L'UPnP è un protocollo di comunicazione che permette ai dispositivi della tua rete interna di configurare in modo automatico l'apertura delle connessioni sul tuo Fastgate.",
                    UPNP_DET: {
                        TITLE: 'Dettagli UPnP',
                        DEST: 'Destinazione',
                        DESC: 'Descrizione',
                        PROT: 'Protocollo',
                        INT_PORT: 'Porta interna',
                        EXT_PORT: 'Porta esterna'
                    },
                    MAPPING: {
                        CONSOLE: {
                            TITLE: 'Port mapping (console)',
                            ID: 'Identificativo',
                            PROT: 'Protocollo',
                            EXT_PORT: 'Porta esterna',
                            INT_PORT: 'Porta interna',
                            ADD_NEW: 'Associa nuovo port mapping a console'
                        },
                        SERVICE: {
                            TITLE: 'Port mapping (servizi)',
                            ADD_NEW: 'Associa nuovo port mapping a servizio'
                        }
                    },
                    MODAL_TITLE_ADD_CONSOLES: 'Associa nuovo port mapping a console',
                    MODAL_TITLE_ADD_SERVICES: 'Associa nuovo port mapping a servizio',
                    MODAL_SEARCH_MODE: 'Metodo di ricerca',
                    MODAL_SEARCH_MODE_AUTO: 'Dispositivi online',
                    MODAL_SEARCH_MODE_MANUAL: 'Aggiunta manuale',
                    MODAL_DEVICE_LIST: 'Lista dispositivi',
                    MODAL_DEVICE_NAME: 'Nome dispositivo',
                    MODAL_ADD_IP_ADDRESS: 'Indirizzo IP',
                    MODAL_ADD_CONSOLES: 'Console',
                    MODAL_ADD_SERVICES: 'Servizio' 
                },
                PORT_CONF_MAN: {
                    TITLE: 'CONFIGURAZIONE MANUALE PORTE',
                    FIREWALL: 'Firewall',
                    MODAL_TITLE_ADD: 'Associa nuovo port mapping',
                    FW_DESC: 'Il Firewall in modalità spento permette tutte le connessioni in uscita senza restrizioni. In ingresso, le connessioni IPv4 sono regolamentate dalle sezioni di DMZ e Port Mapping, le connessioni IPv6 sono senza restrizioni.',
                    PORT_INVALID: 'La porta selezionata non è disponibile, in quanto al momento è utilizzata per servizi interni del tuo FASTGate',
                    PORT_CONFLICTING: 'Le porte selezionate sono in conflitto con una regola esistente.',
                    LEVEL: {
                        TITLE: 'Livello',
                        NAME_1: 'Alto',
                        NAME_2: 'Medio',
                        DESC_1: 'Il Firewall in modalità alto non permette alcuna connessione in uscita e in ingresso.',
                        DESC_2: 'Il Firewall in modalità medio permette solamente l’utilizzo della navigazione web e della posta elettronica. In ingresso, le connessioni IPv4 sono regolamentate dalle sezioni di DMZ e Port Mapping, le connessioni IPv6 sono limitate alle sole risposte dei servizi inizializzati dall’interno.',
                        DESC: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor indicidunt ut labore et dolore magna aliqua.'
                    },
                    DMZ: 'DMZ',
                    DMZ_DESC: 'Fastgate inoltrerà verso il client configurato nella DMZ tutte le connessioni provenienti dalla wan ad esclusione di quelle connessioni presenti in eventuali portmapping configurati.',
                    CLIENT: {
                        TITLE: 'Client configurati',
                        IP: 'Indirizzo IP',
                        ADD_NEW: 'Configura nuovo client'
                    },
                    MAPPING: {
                        TITLE: 'Port mapping',
                        SERVICE: 'Servizio',
                        IP: 'Indirizzo IP',
                        PROT: 'Protocollo',
                        EXT_PORT: 'Porta esterna',
                        INT_PORT: 'Porta interna',
                        ADD_NEW: 'Associa nuovo port mapping'
                    }
                },
                USB_CONF: {
                    TITLE: 'CONFIGURAZIONI USB',
                    DLNA: 'DLNA',
                    DLNA_DESC: 'Il DLNA consente la condivisione di file multimediali all’interno della rete domestica.',
                    PRINT_SERVER: 'Print server',
                    PRINT_SERVER_DESC: 'Il print Server permette la condivisione della stampante collegata al tuo Fastgate con i dispositivi connessi alla rete domestica.',
                    FILE_SHARE: 'Condivisione file',
                    FILE_SHARE_DESC: 'Il servizio di condivisione files permette di condividere i files presenti nei dischi connessi al tuo Fastgate all’interno della rete domestica.',
                    DISKS: {
                        TITLE: 'Dischi di archiviazione',
                        FS: 'File System',
                        TOT_SPACE: 'Spazio totale',
                        FREE_SPACE: 'Spazio libero',
                        EJECT: 'Espelli',
                        EJECT_B: 'Rimozione sicura'
                    },
                    SERVER_NAME: 'Nome host',
                    WORKGROUP: 'Gruppo di lavoro',
                    INTERFACE: {
                        TITLE: 'Interfaccia di archiviazione',
                        LAN: 'LAN',
                        LANWAN: 'LAN e WAN'
                    },
                    DISK_PROTECTION: 'Protezione dischi',
                    ID: 'Nome utente',
                    PASS: 'Password',
                    MOBIL_BKUP: 'Mobile backup',
                    MOBIL_BKUP_DESC: 'Mobile Backup utilizza il modem UMTS connesso al tuo Fastgate, per navigare anche in assenza di connessione.',
                    CONN_STATUS: 'Stato collegamento',
                    SIM_PIN: 'PIN carta SIM',
                    APN: 'Nome access point (APN)',
                    USER: 'Nome utente',
                    ACTIV_TYPE: {
                        TITLE: 'Tipo di attivazione',
                        MAN: 'Manuale',
                        MAN_DESC: 'man Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor indicidunt ut labore et dolore magna aliqua.',
                        MAN2: 'Manuale con disattivazione programmata',
                        MAN2_DESC: 'man 2 Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor indicidunt ut labore et dolore magna aliqua.',
                        AUTO: 'Automatica',
                        AUTO_DESC: 'auto Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor indicidunt ut labore et dolore magna aliqua.'
                    },
                    CONNECT_BK: 'Connetti backup ora',
                    DEACTIVATE_AFTER: 'Disattiva dopo',
                    SECONDS: 'Secondi'
                },
                LAN_CONF: {
                    TITLE: 'IMPOSTAZIONI LAN',
                    LONG_TITLE: 'IMPOSTAZIONI LAN SU RETE PRINCIPALE',
                    FASTGATE_IP: 'Indirizzo IP Fastgate',
                    IP: 'Indirizzo IP',
                    MASK: 'Maschera di sottorete',
                    DHCP: 'Server DHCP',
                    DHCP_POOL_RANGE: 'Intervallo indirizzi IP',
                    VALIDITY: 'Validità lease',
                    MODAL_TITLE_ADD : 'Aggiungi DHCP',
                    MODAL_SEARCH_MODE: 'Metodo di ricerca',
                    MODAL_SEARCH_MODE_AUTO: 'Dispositivi online',
                    MODAL_SEARCH_MODE_MANUAL: 'Aggiunta manuale',
                    MODAL_DEVICE_LIST: 'Lista dispositivi',
                    MODAL_DEVICE_NAME: 'Nome dispositivo',
                    MODAL_ADD_MAC_ADDRESS: 'MAC address',
                    DHCP_DETAILS: {
                        TITLE: 'Associazioni DHCP',
                        MAC: 'Indirizzo MAC',
                        ADD_NEW: 'Aggiungi associazione DHCP'
                    },
                    IPV6_PREFIX: 'Prefisso IPV6 (6RD)',
                    ENABLE_IPV6: 'IPV6 su LAN',
                    IPV6_ON: 'Abilitato',
                    IPV6_OFF: 'Disabilitato'
                }
            },
            MODEM: {
                REFRESH: 'Riavvia le verifiche',
                LED: {
                    TITLE: 'SPIE LED',
                    STATUS: {
                        TITLE: 'Luci di Stato',
                        RESULT: 'Esito',
                        LAST_VERIFICATION: 'Ultima verifica',
                        LINE: {
                            NAME: 'Stato linea',
                            RESULT: {
                                OFF: 'Assente', 
                                ON: 'Presente',
                                NAN: '--'
                            },
                            DESCRIPTION: 'Lo stato linea ti comunica il corretto funzionamento della tua connessione Internet se la luce è verde o spenta.<br /> ' +
                            'Quando la luce è rossa lampeggiante è in corso la sincronizzazione della FASTGate con la linea Internet, che può durare alcuni minuti.<br /> ' +
                            'La luce rossa fissa indica invece che la connettività Internet non è presente: verifica il corretto collegamento del FASTGate alla linea Internet.'
                        },
                        WIFI: {
                            NAME: 'Stato wifi',
                            RESULT: {
                                OFF: 'Spento', 
                                ON: 'Acceso',
                                NAN: '--'
                            },
                            DESCRIPTION: 'Lo stato WiFi ti comunica il corretto funzionamento della rete Wi-Fi se la luce è verde fissa o spenta.<br/>La luce verde lampeggiante indica che è in corso la sintonizzazione sul canale radio migliore.<br/>La luce fissa rossa indica invece che il Wi-Fi è spento oppure che il canale impostato non è il miglior disponibile: vai nella sezione <a ui-sref="wifi" href="#/wifi">WiFi</a> per verificare l’attivazione della rete WiFi e nella sezione <a ui-sref="line" href="#/line">Connessione</a> per verificare il canale utilizzato.'
                        
                        },
                        WPS: {
                            NAME: 'WPS',
                            RESULT: {
                                OFF: 'Spento', 
                                ON: 'Acceso',
                                CON: 'In abbinamento',
                                NAN: '--'
                            },
                            DESCRIPTION: 'Il WPS ti permette di aggiungere nuovi dispositivi alla tua rete senza inserire la password del tuo WiFi. Premi il tasto sul tuo FASTGate finché la luce verde inizierà a lampeggiare. Entro 120 secondi, premi il tasto WPS anche sul dispositivo che vuoi da associare. Al termine dell’operazione una luce verde fissa ti notificherà l’avvenuta connessione.<br/>' +
                                         'La luce rossa fissa indica invece che la connessione non è riuscita: ripeti la procedura descritta oppure configura il tuo dispositivo utilizzando le credenziali WiFi o il QR Code riportato nell’etichetta adesiva o nel retro del modem le credenziali del WiFi.<br/>' +
                                         'Se il WiFi del tuo FASTGate è spento, inoltre, la pressione del tasto WPS ti permette di riattivarlo in maniera semplice.'

                                         
                        }
                    },
                    PRESENCE: 'Luce di presenza',
                    AUTO_OFF: {
                        TITLE: 'Spegnimento automatico',
                        DESCRIPTION: 'Spegnimento delle luci durante le ore notturne per evitare disturbi. Non saranno impattate le prestazioni WiFi.'
                    }
                },
                LINE: {
                    TITLE: 'VERIFICHE LINEA',
                    TITLE_M: 'VERIFICHE',
                    LABELS: {
                        STATUS: 'Stato Linea', DETAILS: 'Dettagli', VERIFY: 'Verifica', RESULT: 'Esito',
                        LINE: 'Linea', IPV4: 'Indirizzo IPV4', HOP_PING: 'Prossimo Hop Ping', DNS_PING: 'Primo DNS Server Ping'
                    },
                    DESC_END: 'Accedi alla sezione <a href="#/line">Linea</a> per verificare la velocità di allineamento.',
                    MESSAGES: {
                        STATUS: {
                            OK: {
                                SHORT: 'OK',
                                DESC: 'Nessun problema riscontrato.'
                            },
                            NOK: {
                                SHORT: 'Errore',
                                DESC: 'Si è verificato un problema nella linea.'
                            }
                        },
                        LINE: {
                            OK: {
                                SHORT: 'Presente',
                                DESC: 'La linea è attiva, con presenza di servizi internet.'
                            },
                            NOK: {
                                SHORT: 'Assente',
                                DESC: 'La linea non è attiva.'
                            }
                        },
                        IPV4: {
                            OK: {
                                SHORT: 'Rilevato, ',
                                DESC: 'L\'indirizzo IP è correttamente configurato.'
                            },
                            NOK: {
                                SHORT: 'Assente',
                                DESC: 'Nessun IP.'
                            }
                        },
                        HOP: {
                            OK: {
                                SHORT: 'Positivo'
                            },
                            NOK: {
                                SHORT: 'Negativo'
                            }
                        },
                        DNS: {
                            OK: {
                                SHORT: 'Positivo'
                            },
                            NOK: {
                                SHORT: 'Negativo'
                            }
                        }
                    }
                },
                WIFI: {
                    TITLE: 'VERIFICHE WIFI',
                    LABELS: {
                        STATUS: 'Stato WiFi', STATUS2: 'Stato', DETAILS: 'Dettagli', WIFI: 'WiFi', SECURITY: 'Protezione',
                        F5GHZ: 'WiFi 5 GHz', F24GHZ: 'WiFi 2,4 GHz'
                    },
                    MESSAGES: {
                        STATUS: {
                            OK: 'OK', NOK: 'Errore'
                        },
                        ACTIVE: 'Attivo', INACTIVE: 'Inattivo'
                    }
                },
                PORTS: {
                    TITLE: 'VERIFICHE PORTE',
                    LABELS: {
                        ETH: 'Stato porte ethernet',
                        USB: 'Stato usb',
                        OK: 'Connesso',
                        NOK: 'Disconnesso',
                        NAME: 'Nome',
                        PORT: 'Porta',
                        STATUS: 'Stato'
                    }
                }
            },
            VOICE:{
                CALL_LIST:{
                    TITLE: 'REGISTRO CHIAMATE',
                    TABLE: {
                        TITLE: 'Dettagli storico',
                        RECEIVED : 'Ricevute',
                        LOST: 'Perse',
                        DONE: 'Effettuate',
                        ALL: 'Tutte',
                        DATE: 'Data',
                        HOURS: 'Ora',
                        NUMBER: 'Numero',
                        DURATION: 'Durata',
                        DELETE: 'Elimina',
                        DELETE_ALL: 'Elimina tutti'
                    }
                }
            },
						ONT: {
                TECH_INFO: {
                    TITLE: 'ONT',
                    BUTTON: 'GPON-Bridge',
                    INFOTOP: 'Abilitare la modalità GPON-Bridge per utilizzare un proprio Router aggiuntivo',
                    INFOBOTTOM: '<b>Attenzione:</b> abilitando la modalità GPON-Bridge si perderà la connessione ad Internet ed il Fastgate non sarà più accessibile dal proprio browser. </br>Sarà indispensabile un Router aggiuntivo collegato al Fastgate per ristabilire una connessione ad Internet',

                },
            }
        }
    });
