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

    public string[] getBlockDevices() {
        Gee.ArrayList<string> devs = new Gee.ArrayList<string>();
        var dir = File.new_for_path("/sys/block");
        try {
            var children = dir.enumerate_children("standard::*", GLib.FileQueryInfoFlags.NONE);
            FileInfo fi;
            while ((fi = children.next_file()) != null) {
                var name = fi.get_name();
                string res;
                GLib.FileUtils.get_contents("/sys/block/" + name + "/size", out res);
                if (res.strip() == "0") continue;
                devs.add(name);
            }
        } catch (Error e) {
            printerr("Could not get block devices: %s", e.message);
        }
        return devs.to_array();
    }

    public string? readFile(string path) {
        string res;
        try {
            GLib.FileUtils.get_contents(path, out res);
        } catch (FileError e) {
            print("Could not read %s: %s\n", path, e.message);
            return null;
        }
        return res;
    }

    public string[] splitStr(string str, string delim) {
        var split = str.split_set(delim);
        Gee.ArrayList<string> al = new Gee.ArrayList<string>.wrap(split);
        var f = al.filter((v) => v != "");
        return iteratorToArray<string>(f);
    }

    public T[] iteratorToArray <T> (Gee.Iterator<T> it) {
        Gee.ArrayList<T> res = new Gee.ArrayList<T>();
        res.add_all_iterator(it);
        return res.to_array();
    }
}
