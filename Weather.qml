pragma Singleton

// Clima atual via wttr.in (geolocalização por IP), atualizado a cada 10 min.
// IPC: qs -c lumen ipc call weather refresh

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool available: false
    property int tempC: 0
    property int high: 0
    property int low: 0
    property int rainChance: 0
    property string desc: ""
    property string icon: "\u{F0599}" // nf-md-weather-sunny
    property var hourly: []
    property string area: ""

    // Coordenadas da sua cidade no wttr.in (padrão: Brasília).
    // Troque para a sua: https://wttr.in/<lat>,<lon>
    readonly property string location: "-15.7939,-47.8828"

    function refresh() {
        if (!fetch.running)
            fetch.running = true;
    }

    // WWO weather codes -> ícone (Material Design Icons)
    function iconFor(code) {
        if (code === 113)
            return "\u{F0599}"; // sunny
        if (code === 116)
            return "\u{F0595}"; // partly cloudy
        if (code === 119 || code === 122)
            return "\u{F0590}"; // cloudy
        if (code === 143 || code === 248 || code === 260)
            return "\u{F0591}"; // fog
        if (code === 200 || code === 386 || code === 389)
            return "\u{F0593}"; // lightning
        if ([227, 230, 320, 323, 326, 329, 332, 335, 338, 368, 371, 374, 377].indexOf(code) >= 0)
            return "\u{F0598}"; // snowy
        if (code === 353 || code === 356 || code === 359)
            return "\u{F0596}"; // pouring
        return "\u{F0597}"; // rainy
    }

    function descFor(code) {
        if (code === 113)
            return "Céu limpo";
        if (code === 116)
            return "Parcialmente nublado";
        if (code === 119 || code === 122)
            return "Nublado";
        if (code === 143 || code === 248 || code === 260)
            return "Nevoeiro";
        if (code === 200 || code === 386 || code === 389)
            return "Trovoada";
        if ([227, 230, 320, 323, 326, 329, 332, 335, 338, 368, 371, 374, 377].indexOf(code) >= 0)
            return "Neve";
        if ([350, 362, 365, 374].indexOf(code) >= 0)
            return "Chuva congelante";
        return "Chuva";
    }

    Process {
        id: fetch

        command: ["curl", "-s", "--max-time", "12", "https://wttr.in/" + root.location + "?format=j1"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const c = d.current_condition[0];
                    const w0 = d.weather[0];
                    const w1 = d.weather.length > 1 ? d.weather[1] : null;

                    root.tempC = Number(c.temp_C);
                    root.desc = root.descFor(Number(c.weatherCode));
                    root.icon = root.iconFor(Number(c.weatherCode));
                    root.high = Number(w0.maxtempC);
                    root.low = Number(w0.mintempC);
                    root.rainChance = Number(w0.hourly[0].chanceofrain);
                    root.area = d.nearest_area[0].areaName[0].value;

                    // próximas 2 horas (com todos os detalhes)
                    const nowH = new Date().getHours();
                    const list = [];
                    for (let i = 0; i < w0.hourly.length; ++i) {
                        const h = Math.floor(Number(w0.hourly[i].time) / 100);
                        if (h < nowH)
                            continue;
                        list.push({
                            label: h + "h",
                            temp: Number(w0.hourly[i].tempC),
                            feels: Number(w0.hourly[i].FeelsLikeC),
                            humidity: Number(w0.hourly[i].humidity),
                            wind: Number(w0.hourly[i].windspeedKmph),
                            windDir: w0.hourly[i].winddir16Point,
                            rain: Number(w0.hourly[i].chanceofrain),
                            icon: root.iconFor(Number(w0.hourly[i].weatherCode))
                        });
                    }
                    if (w1 !== null) {
                        for (let i = 0; i < w1.hourly.length && list.length < 2; ++i) {
                            const h = Math.floor(Number(w1.hourly[i].time) / 100);
                            list.push({
                                label: h + "h",
                                temp: Number(w1.hourly[i].tempC),
                                feels: Number(w1.hourly[i].FeelsLikeC),
                                humidity: Number(w1.hourly[i].humidity),
                                wind: Number(w1.hourly[i].windspeedKmph),
                                windDir: w1.hourly[i].winddir16Point,
                                rain: Number(w1.hourly[i].chanceofrain),
                                icon: root.iconFor(Number(w1.hourly[i].weatherCode))
                            });
                        }
                    }
                    root.hourly = list.slice(0, 2);
                    root.available = true;
                } catch (e) {
                    console.warn("[lumen] weather: falha ao ler", e);
                }
            }
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    IpcHandler {
        target: "weather"

        function refresh(): void { root.refresh(); }
    }
}
