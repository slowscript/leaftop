namespace Leaftop {
    class ResourceWatcher {
        public const int ChartHistoryLength = 60; // 60 s
        public const uint UPDATE_INTERVAL = 1000; // 1 s

        ChartButton btnProcessor;
        ChartButton btnMemory;
        Gee.HashMap<string, DiskStats> diskStats = new Gee.HashMap<string, DiskStats>();

        private unowned Gtk.Stack stack;
        private Gtk.Box diskButtonBox;
        private ProcessorPage pageProcessor;
        private MemoryPage pageMemory;

        private long prevCpuTime = 0;

        public void init_switcher_buttons(Gtk.Box container) {
            btnProcessor = new ChartButton();
            btnProcessor.Title = _("Processor");
            btnProcessor.clicked.connect(() => stack.set_visible_child(pageProcessor));
            btnProcessor.chart.DataPoints = new float[ChartHistoryLength];
            container.append(btnProcessor);

            btnMemory = new ChartButton();
            btnMemory.Title = _("Memory");
            btnMemory.clicked.connect(() => stack.set_visible_child(pageMemory));
            btnMemory.chart.DataPoints = new float[ChartHistoryLength];
            btnMemory.chart.ChartColor = {0.91f, 0.31f, 0.91f, 1.0f};
            btnMemory.chart.ChartFill = {0.91f, 0.31f, 0.91f, 0.5f};
            container.append(btnMemory);

            diskButtonBox = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            container.append(diskButtonBox);
        }

        public void init_stack_pages(Gtk.Stack _stack) {
            stack = _stack;

            pageProcessor = new ProcessorPage();
            pageProcessor.chart.DataPoints = new float[ChartHistoryLength];
            string cpuinfo = readProcFile("cpuinfo");
            pageProcessor.lblProcessorName.label = cpuinfo.split("\n")[4].split(":")[1].strip();
            stack.add_child(pageProcessor);

            pageMemory = new MemoryPage();
            pageMemory.chart.DataPoints = new float[ChartHistoryLength];
            pageMemory.chart.ChartColor = {0.91f, 0.31f, 0.91f, 1.0f};
            pageMemory.chart.ChartFill = {0.91f, 0.31f, 0.91f, 0.5f};
            string meminfo = readProcFile("meminfo");
            string[] totalmemarr = meminfo.split("\n")[0].split(" ");
            uint totalmem = uint.parse(totalmemarr[totalmemarr.length-2]);
            pageMemory.lblMemSize.label = Utils.humanSize(totalmem, 1, 2);
            stack.add_child(pageMemory);
        }

        public void start_watching() {
            Timeout.add(UPDATE_INTERVAL, update);
        }

        private bool update() {
            updateCPU();
            updateMemory();
            updateDisk();
            return true;
        }

        private void updateCPU() {
            string res;
            try {
                GLib.FileUtils.get_contents("/proc/stat", out res);
            } catch (FileError e) {
                print("Could not read /proc/stat: %s\n", e.message);
                return;
            }
            string[] lines = res.split("\n");
            long cpuUser = long.parse(lines[0].split(" ")[2]);
            long cpuNice = long.parse(lines[0].split(" ")[3]);
            long cpuSystem = long.parse(lines[0].split(" ")[4]);
            long cpu = (cpuUser + cpuNice + cpuSystem);
            if (prevCpuTime == 0) prevCpuTime = cpu;
            float cpuUtil = (float)(cpu - prevCpuTime) / ProcessWatcher.CLK_TCK / get_num_processors(); // Assuming 1s update freq
            prevCpuTime = cpu;

            pageProcessor.chart.push_value(cpuUtil);
            btnProcessor.chart.push_value(cpuUtil);
            btnProcessor.Status = "%d %%".printf((int)(cpuUtil*100.0f));
        }

        private void updateMemory() {
            string res;
            try {
                GLib.FileUtils.get_contents("/proc/meminfo", out res);
            } catch (FileError e) {
                print("Could not read /proc/meminfo: %s\n", e.message);
                return;
            }
            string[] lines = res.split("\n");
            string[] totalmemarr = lines[0].split(" ");
            uint totalmem = uint.parse(totalmemarr[totalmemarr.length-2]);

            string[] availmemarr = lines[2].split(" ");
            uint availmem = uint.parse(availmemarr[availmemarr.length-2]);
            float memusage = 1.0f - ((float)availmem / totalmem);

            pageMemory.chart.push_value(memusage);
            btnMemory.chart.push_value(memusage);
            btnMemory.Status = "%s / %s (%d %%)".printf(Utils.humanSize(totalmem - availmem, 1, 2), 
                Utils.humanSize(totalmem, 1, 2), (int)(memusage*100.0));
        }

        private void updateDisk() {
            var devs  = Utils.getBlockDevices();
            foreach (var dev in devs) {
                if (!diskStats.keys.contains(dev)) {
                    print("Disk added: %s\n", dev);
                    var ds = new DiskStats(dev);
                    diskButtonBox.append(ds.btn);
                    stack.add_child(ds.page);
                    ds.btn.clicked.connect(() => stack.set_visible_child(ds.page));
                    diskStats.set(dev, ds);
                }
            }
            var toRemove = Utils.iteratorToArray<string>(diskStats.keys.filter((dev) => !(dev in devs)));
            foreach (var disk in toRemove) {
                print("Disk removed: %s\n", disk);
                diskButtonBox.remove(diskStats.get(disk).btn);
                stack.remove(diskStats.get(disk).page);
                diskStats.unset(disk);
            }
            foreach (var disk in diskStats.keys)
                diskStats.get(disk).update();
        }

        private string? readProcFile(string file) {
            string path = "/proc/" + file;
            string res;
            try {
                GLib.FileUtils.get_contents(path, out res);
            } catch (FileError e) {
                print("Could not read %s: %s\n", path, e.message);
                return null;
            }
            return res;
        }
    }

    class DiskStats {
        public string Device;
        public string Model;

        public long io_ticks;
        long last_io_ticks = 0;

        public ChartButton btn;
        public DiskPage page;

        public DiskStats(string device) {
            Device = device;
            Model = (Utils.readFile("/sys/block/" + Device + "/device/model") ?? "").strip();

            btn = new ChartButton();
            btn.chart.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            btn.chart.ChartColor = {0.96f, 0.74f, 0.18f, 1.0f};
            btn.chart.ChartFill = {0.96f, 0.74f, 0.18f, 0.5f};
            btn.Title = _("Disk (%s)").printf(Device);

            page = new DiskPage();
            page.lblDiskModel.label = Model;
            page.lblTitle.label = btn.Title;
            page.chart.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            page.chart.ChartColor = {0.96f, 0.74f, 0.18f, 1.0f};
            page.chart.ChartFill = {0.96f, 0.74f, 0.18f, 0.5f};
        }

        public void update() {
            string res;
            try {
                GLib.FileUtils.get_contents("/sys/block/" + Device + "/stat", out res);
                var stats = Utils.splitStr(res, " ");
                io_ticks = long.parse(stats[9], 10); // In milliseconds
                //print("%s: %ld\n", Device, io_ticks - last_io_ticks);
            } catch (FileError e) {
                print("Could not read disk stats: %s\n", e.message);
            }
            if (last_io_ticks == 0) last_io_ticks = io_ticks;
            float active_pct = (float)(io_ticks - last_io_ticks) / ResourceWatcher.UPDATE_INTERVAL;
            
            btn.Status = "%s\n%.1f %%".printf(Model, active_pct*100.0f);
            btn.chart.push_value(active_pct);
            page.chart.push_value(active_pct);

            last_io_ticks = io_ticks;
        }
    }
}