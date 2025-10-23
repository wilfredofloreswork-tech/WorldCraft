// gps_bridge.js
var GodotGPS = {
    watchId: null,
    
    startWatching: function(callback) {
        if (!navigator.geolocation) {
            console.error("Geolocation not supported by browser");
            return false;
        }
        
        console.log("Starting GPS watch...");
        
        this.watchId = navigator.geolocation.watchPosition(
            function(position) {
                console.log("GPS position received:", position.coords.latitude, position.coords.longitude);
                var data = {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    accuracy: position.coords.accuracy,
                    altitude: position.coords.altitude || 0,
                    timestamp: position.timestamp
                };
                callback(JSON.stringify(data));
            },
            function(error) {
                console.error("GPS Error:", error.message);
                var errorData = {
                    error: error.message,
                    code: error.code
                };
                callback(JSON.stringify(errorData));
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
        
        console.log("GPS watch started, ID:", this.watchId);
        return true;
    },
    
    stopWatching: function() {
        if (this.watchId !== null) {
            navigator.geolocation.clearWatch(this.watchId);
            console.log("GPS watch stopped");
            this.watchId = null;
        }
    },
    
    getCurrentPosition: function(callback) {
        if (!navigator.geolocation) {
            console.error("Geolocation not supported by browser");
            return false;
        }
        
        navigator.geolocation.getCurrentPosition(
            function(position) {
                var data = {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    accuracy: position.coords.accuracy,
                    altitude: position.coords.altitude || 0,
                    timestamp: position.timestamp
                };
                callback(JSON.stringify(data));
            },
            function(error) {
                console.error("GPS Error:", error.message);
                var errorData = {
                    error: error.message,
                    code: error.code
                };
                callback(JSON.stringify(errorData));
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
        
        return true;
    }
};

console.log("GodotGPS bridge loaded");