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

    int parse_suffix(string s, bool si = false) {
        int suffix_start = -1;
        int mult = si ? 1000 : 1024;
        for (int i = 0; i < s.length; i++) {
            if (!s[i].isdigit()) {
                suffix_start = i;
                break;
            }    
        }
        if (suffix_start == -1) //All digits
            return int.parse(s);
        else if (suffix_start == 0) //No digits
            return 0;
        else {
            int num = int.parse(s[0:suffix_start]);
            switch (s[suffix_start].tolower()) {
                case 'k':
                    return num * mult;
                case 'm':
                    return num * mult * mult;
                case 'g':
                    return num * mult * mult * mult;
                default:
                    return num;
            }
        }
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
            var children = dir.enumerate_children(FileAttribute.STANDARD_NAME, GLib.FileQueryInfoFlags.NONE);
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

    public string[] getNetworkInterfaces() {
        Gee.ArrayList<string> ifs = new Gee.ArrayList<string>();
        var dir = File.new_for_path("/sys/class/net");
        try {
            var children = dir.enumerate_children(FileAttribute.STANDARD_NAME, GLib.FileQueryInfoFlags.NONE);
            FileInfo fi;
            while ((fi = children.next_file()) != null) {
                var name = fi.get_name();
                if (name == "lo") continue;
                if (readFile("/sys/class/net/" + name + "/carrier")?.strip() != "1") continue;
                ifs.add(name);
            }
        } catch (Error e) {
            printerr("Could not get network interfaces: %s\n", e.message);
        }
        return ifs.to_array();
    }

    public string? readFile(string path, bool verbose = false) {
        string res;
        try {
            GLib.FileUtils.get_contents(path, out res);
        } catch (FileError e) {
            if (verbose)
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

    public Gee.ArrayList<FileInfo> enumerate_dir(string path) throws Error {
        var dir = File.new_for_path(path);
        var res = new Gee.ArrayList<FileInfo>();
        var children = dir.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
        FileInfo info;
        while ((info = children.next_file()) != null) {
            res.add(info);
        }
        return res;
    }
}
