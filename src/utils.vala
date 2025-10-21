namespace Leaftop.Utils {
    const string[] UNITS = {"kB", "MB", "GB"};

    string humanSize(float sizekb, int decimals = 2, int max_unit = 1) {
        int unit = 0;
        float sz = sizekb;
        while (sz >= 1024 && unit < UNITS.length-1 && unit < max_unit) {
            sz /= 1024;
            unit++;
        }
        return ("%." + decimals.to_string() + "f %s").printf(sz, UNITS[unit]);
    }

    private static Gee.HashMap<string,int> _signalNameToInt = null;

    public Gee.HashMap<string,int> signalNameToInt() {
        if (_signalNameToInt == null) {
            _signalNameToInt = new Gee.HashMap<string, int>();
            _signalNameToInt["sighup"] = 1;
            _signalNameToInt["sigint"] = 2;
            _signalNameToInt["sigkill"] = 9;
            _signalNameToInt["sigterm"] = 15;
        }
        return _signalNameToInt;
    }
}
