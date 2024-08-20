namespace Leaftop.Utils {
    const string[] UNITS = {"kB", "MB"};

    string humanSize(float sizekb) {
        int unit = 0;
        float sz = sizekb;
        while (sz >= 1024 && unit < UNITS.length-1) {
            sz /= 1024;
            unit++;
        }
        return "%.2f %s".printf(sz, UNITS[unit]);
    }
}
