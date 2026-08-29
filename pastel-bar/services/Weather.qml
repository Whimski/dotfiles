pragma Singleton
import QtQuick
import ".."

// Weather via Open-Meteo (open-meteo.com) — free, no API key, no signup.
// Location comes from Settings (weatherLat/weatherLon); if unset, we auto-detect
// once from the machine's IP (ipapi.co) and seed Settings. Refreshes every 15 min.
QtObject {
    id: w

    // ---- current conditions ----
    property real temp: 0
    property real feelsLike: 0
    property int code: -1              // WMO weather code
    property bool isDay: true
    property real humidity: 0
    property real wind: 0
    property real high: 0
    property real low: 0
    property string city: (Settings.weatherLoc && Settings.weatherLoc.city) || ""
    property string desc: ""
    property string icon: "cloud"
    property var daily: []             // [{ day, icon, code, max, min }, …]

    property bool loading: false
    property string error: ""
    property double lastUpdated: 0     // ms epoch, 0 = never

    readonly property bool fahrenheit: Settings.weatherUnit === "fahrenheit"
    readonly property string unitSuffix: fahrenheit ? "°F" : "°C"

    // ---- WMO code → glyph / label ----
    function iconFor(c, day) {
        if (c === 0 || c === 1) return day ? "sun" : "moon"
        if (c === 2) return "cloudSun"
        if (c === 3) return "cloud"
        if (c >= 45 && c <= 48) return "fog"
        if (c >= 51 && c <= 67) return "rain"
        if (c >= 71 && c <= 77) return "snow"
        if (c >= 80 && c <= 82) return "rain"
        if (c >= 85 && c <= 86) return "snow"
        if (c >= 95) return "storm"
        return "cloud"
    }
    function descFor(c) {
        var m = {
            0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
            45: "Fog", 48: "Rime fog",
            51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
            56: "Freezing drizzle", 57: "Freezing drizzle",
            61: "Light rain", 63: "Rain", 65: "Heavy rain",
            66: "Freezing rain", 67: "Freezing rain",
            71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
            80: "Light showers", 81: "Showers", 82: "Heavy showers",
            85: "Snow showers", 86: "Snow showers",
            95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm"
        }
        return m[c] || "—"
    }

    function _get(url, onOk) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try { onOk(JSON.parse(xhr.responseText)) }
                catch (e) { w.loading = false; w.error = "Bad response" }
            } else {
                w.loading = false
                w.error = "Network error"
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    // Public: fetch weather now. Auto-detects location first if none is stored.
    function refresh() {
        w.loading = true
        w.error = ""
        var loc = Settings.weatherLoc || ({})
        if (loc.lat === undefined || loc.lon === undefined) _geolocate()
        else _fetchWeather(loc.lat, loc.lon)
    }

    // Look up a city by name (Open-Meteo geocoding) and switch to it.
    function setLocation(name) {
        var q = ("" + name).trim()
        if (q === "") return
        w.loading = true; w.error = ""
        _get("https://geocoding-api.open-meteo.com/v1/search?name="
             + encodeURIComponent(q) + "&count=1&language=en&format=json",
             function(d) {
                 if (!d.results || d.results.length === 0) {
                     w.loading = false; w.error = "City not found"; return
                 }
                 var r = d.results[0]
                 var city = r.name + (r.country_code ? ", " + r.country_code : "")
                 Settings.setWeatherLoc(r.latitude, r.longitude, city)
                 w.city = city
                 _fetchWeather(r.latitude, r.longitude)
             })
    }

    function _geolocate() {
        // ipwho.is: free, HTTPS, no key. { latitude, longitude, city, country_code }
        _get("https://ipwho.is/", function(d) {
            if (d && d.success && d.latitude !== undefined) {
                var city = (d.city || "") + (d.country_code ? ", " + d.country_code : "")
                Settings.setWeatherLoc(d.latitude, d.longitude, city)
                w.city = city
                _fetchWeather(d.latitude, d.longitude)
            } else {
                w.loading = false; w.error = "Location unavailable"
            }
        })
    }

    function _fetchWeather(lat, lon) {
        var unit = w.fahrenheit ? "fahrenheit" : "celsius"
        var wind = w.fahrenheit ? "mph" : "kmh"
        var url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,"
            + "weather_code,wind_speed_10m,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&temperature_unit=" + unit + "&wind_speed_unit=" + wind
            + "&timezone=auto&forecast_days=5"
        _get(url, function(d) {
            var c = d.current || {}
            w.temp = Math.round(c.temperature_2m)
            w.feelsLike = Math.round(c.apparent_temperature)
            w.humidity = Math.round(c.relative_humidity_2m)
            w.wind = Math.round(c.wind_speed_10m)
            w.code = c.weather_code
            w.isDay = c.is_day === 1
            w.desc = descFor(c.weather_code)
            w.icon = iconFor(c.weather_code, w.isDay)

            var dl = d.daily || {}
            var out = []
            var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            if (dl.time) {
                for (var i = 0; i < dl.time.length; i++) {
                    var dt = new Date(dl.time[i])
                    out.push({
                        day: i === 0 ? "Today" : names[dt.getDay()],
                        code: dl.weather_code[i],
                        icon: iconFor(dl.weather_code[i], true),
                        max: Math.round(dl.temperature_2m_max[i]),
                        min: Math.round(dl.temperature_2m_min[i])
                    })
                }
                if (out.length > 0) { w.high = out[0].max; w.low = out[0].min }
            }
            w.daily = out
            w.loading = false
            w.lastUpdated = Date.now()
        })
    }

    // Re-fetch when the unit preference changes (values must be re-requested).
    property Connections _cx: Connections {
        target: Settings
        function onWeatherUnitChanged() { if (w.lastUpdated > 0) w.refresh() }
    }

    property Timer _refreshTimer: Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: w.refresh()
    }

    Component.onCompleted: refresh()
}
