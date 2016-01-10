# Websocket-API Dokumentation
Alternativ zum Zugriff auf Steuerungsfunktionen via DBus bietet der THOMAS-Server auch eine Websocket-API an, welche den Zugriff auf die verfügbaren Methoden und Signale von verschiedenen Plattformen aus erleichtert.

## Methoden
### Client => Server
```
{
    "action": "callMethod",
    "methodName": "setMotorSpeed",
    "responseId": "<EINMALIGE ID>",
    "args": {
        "motor": "left",
        "speed": 255
    }
}
```

### Server => Client

```
{
    "action": "methodResponse",
    "methodName": "setMotorSpeed",
    "responseId": "<EINMALIGE ID>",
    "returnedValue": true
}
```

## Signale
### Server => Client

```
{
    "action": "signalCalled",
    "signalName": "cameraStreamRegistered",
    "args": {
        "streamerId": 2
    }
}
```