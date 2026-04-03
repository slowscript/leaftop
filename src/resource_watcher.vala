namespace Leaftop {
    class ResourceWatcher {
        public const int ChartHistoryLength = 61; // 60 s
        public const uint UPDATE_INTERVAL = 1000; // 1 s

        ChartButton btnProcessor;
        ChartButton btnMemory;
        Gee.HashMap<string, DiskStats> diskStats = new Gee.HashMap<string, DiskStats>();
        Gee.HashMap<string, NetStats> netStats = new Gee.HashMap<string, NetStats>();

        private unowned Gtk.Stack stack;
        private Gtk.Box diskButtonBox;
        private Gtk.Box networkButtonBox;
        private ProcessorPage pageProcessor;
        private MemoryPage pageMemory;
        private Gtk.ScrolledWindow pageMemoryScrolled;
        public unowned Gtk.Label lblCPUTotal;
        public unowned Gtk.Label lblMemTotal;
        public unowned Gtk.Label lblDiskTotal;
        public unowned Gtk.Label lblNetTotal;

        private int numCpus = 1;
        private CPUStats[] cpuStats;

        public void init_switcher_buttons(Gtk.Box container) {
            btnProcessor = new ChartButton();
            btnProcessor.Title = _("Processor");
            btnProcessor.clicked.connect(() => stack.set_visible_child(pageProcessor));
            btnProcessor.chart.DataPoints = new float[ChartHistoryLength];
            container.append(btnProcessor);

            btnMemory = new ChartButton();
            btnMemory.Title = _("Memory");
            btnMemory.clicked.connect(() => stack.set_visible_child(pageMemoryScrolled));
            btnMemory.chart.DataPoints = new float[ChartHistoryLength];
            btnMemory.chart.ChartColor = {0.91f, 0.31f, 0.91f, 1.0f};
            btnMemory.chart.ChartFill = {0.91f, 0.31f, 0.91f, 0.5f};
            container.append(btnMemory);

            diskButtonBox = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            container.append(diskButtonBox);
            networkButtonBox = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            container.append(networkButtonBox);
        }

        public void init_stack_pages(Gtk.Stack _stack) {
            stack = _stack;
            numCpus = get_num_cpus();
            cpuStats = new CPUStats[numCpus+1];

            pageProcessor = new ProcessorPage();
            pageProcessor.init(numCpus);
            stack.add_child(pageProcessor);

            pageMemoryScrolled = new Gtk.ScrolledWindow();
            pageMemory = new MemoryPage();
            pageMemory.chart.DataPoints = new float[ChartHistoryLength];
            pageMemory.chartSwap.DataPoints = new float[ChartHistoryLength];
            pageMemory.init();
            string meminfo = readProcFile("meminfo");
            string[] totalmemarr = meminfo.split("\n")[0].split(" ");
            uint totalmem = uint.parse(totalmemarr[totalmemarr.length-2]);
            pageMemory.lblMemSize.label = Utils.humanSize(totalmem, 1, 2);
            pageMemoryScrolled.set_child(pageMemory);
            stack.add_child(pageMemoryScrolled);
        }

        private int get_num_cpus() {
            string? stat = readProcFile("stat");
            if (stat == null)
                return 1;
            string[] lines = stat.split("\n");
            int n = 0;
            for (int i = 1; i < lines.length; i++) {
                if (lines[i].has_prefix("cpu"))
                    n++;
                else break;
            }
            print("Num CPUs: %d\n", n);
            return n;
        }

        public void start_watching() {
            Timeout.add(UPDATE_INTERVAL, update);
        }

        private bool update() {
            updateCPU();
            updateMemory();
            updateDisk();
            updateNetwork();
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
            cpuStats[0].update(lines[0], numCpus);
            for (int i = 1; i < numCpus+1; i++) {
                cpuStats[i].update(lines[i], 1);
                pageProcessor.cpuCharts[i-1].push_value(cpuStats[i].cpuUtil);
            }

            pageProcessor.singleChart.push_value(cpuStats[0].cpuUtil);
            btnProcessor.chart.push_value(cpuStats[0].cpuUtil);
            btnProcessor.Status = "%.0f %%".printf(cpuStats[0].cpuUtil*100.0f);
            lblCPUTotal.label = _("CPU: %.1f %%").printf(cpuStats[0].cpuUtil*100.0f);

            if (stack.visible_child == pageProcessor) {
                pageProcessor.lblUsage.label = "%.0f %%".printf(cpuStats[0].cpuUtil*100.0f);
                string[] cpuinfo = Utils.readFile("/proc/cpuinfo").split("\n");
                float speed = 0.0f;
                foreach (string line in cpuinfo){
                    if (line.has_prefix("cpu MHz")) {
                        float s = float.parse(line.split(":")[1].strip());
                        if (s > speed) speed = s;
                    }
                }
                pageProcessor.lblFrequency.label = "%.2f GHz".printf(speed / 1000.0f);
                pageProcessor.lblProcesses.label = ProcessWatcher.numProcesses.to_string("%d");
                pageProcessor.lblThreads.label = ProcessWatcher.numThreads.to_string("%d");
                pageProcessor.lblDescriptors.label = Utils.readFile("/proc/sys/fs/file-nr").split("\t", 2)[0];
                int uptime = (int)float.parse( Utils.readFile("/proc/uptime").split(" ", 2)[0]);
                int up_days = uptime / 86400;
                int up_hours = (uptime % 86400) / 3600;
                int up_minutes = (uptime % 3600) / 60;
                int up_seconds = uptime % 60;
                pageProcessor.lblUptime.label = "%1d:%02d:%02d:%02d".printf(up_days, up_hours, up_minutes, up_seconds);
            }
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
            uint totalmem = uint.parse(Utils.splitStr(lines[0], " ")[1]);
            uint availmem = uint.parse(Utils.splitStr(lines[2], " ")[1]);
            float memusage = 1.0f - ((float)availmem / totalmem);

            uint totalswapkb = uint.parse(Utils.splitStr(lines[14], " ")[1]);
            uint availswapkb = uint.parse(Utils.splitStr(lines[15], " ")[1]);
            float swapusage = totalswapkb == 0 ? 0.0f : 1.0f - ((float)availswapkb / totalswapkb);

            uint bufferkb =  uint.parse(Utils.splitStr(lines[3], " ")[1]);
            uint cachekb =  uint.parse(Utils.splitStr(lines[4], " ")[1]);
            float freepct = (float)uint.parse(Utils.splitStr(lines[1], " ")[1]) / totalmem;
            float bufferpct = (float)bufferkb / totalmem;
            float cachepct = (float)cachekb / totalmem;
            float usedpct = 1.0f - freepct - bufferpct - cachepct;

            pageMemory.chart.push_value(memusage);
            pageMemory.chartSwap.push_value(swapusage);
            btnMemory.chart.push_value(memusage);
            btnMemory.Status = "%s / %s (%d %%)".printf(Utils.humanSize(totalmem - availmem, 1, 2), 
                Utils.humanSize(totalmem, 1, 2), (int)(memusage*100.0));
            lblMemTotal.label = _("Memory: %.1f %%").printf(memusage * 100.0f);
            pageMemory.lblSwapTotal.label = Utils.humanSize(totalswapkb, 1, 2);
            pageMemory.chartSwap.visible = totalswapkb != 0;
            pageMemory.memoryBar.Values[0] = usedpct;
            pageMemory.memoryBar.Values[1] = bufferpct;
            pageMemory.memoryBar.Values[2] = cachepct;
            pageMemory.lblUsed.label = Utils.humanSize(totalmem - availmem, 2, 2);
            pageMemory.lblBuffer.label = Utils.humanSize(bufferkb, 2, 2);
            pageMemory.lblCache.label = Utils.humanSize(cachekb, 2, 2);
            pageMemory.lblAvailable.label = Utils.humanSize(availmem, 2, 2);
            pageMemory.lblUsedSwap.label = Utils.humanSize(totalswapkb - availswapkb, 2, 2);
        }

        private void updateDisk() {
            var devs  = Utils.getBlockDevices();
            updateResource(devs, diskStats, diskButtonBox, (dev) => new DiskStats(dev));
            float maxUsage = 0.0f;
            foreach (var d in diskStats.values) {
                if (d.active_pct > maxUsage)
                    maxUsage = d.active_pct;
            }
            lblDiskTotal.label = _("Disk: %.1f %%").printf(maxUsage * 100.0f);
        }

        private void updateNetwork() {
            var ifs = Utils.getNetworkInterfaces();
            updateResource(ifs, netStats, networkButtonBox, (dev) => new NetStats(dev));
            float totalSpeed = 0.0f;
            foreach (var n in netStats.values) {
                totalSpeed += n.rx_speed + n.tx_speed;
            }
            lblNetTotal.label = _("Network: %s/s").printf(Utils.humanSize(totalSpeed/1024, 1, 2));
        }

        delegate ResourceStats newResourceStats(string device);
        private void updateResource(string[] devices, Gee.HashMap<string, ResourceStats> deviceMap, Gtk.Box buttonBox, newResourceStats nrs) {
            foreach (var dev in devices) {
                if (!deviceMap.keys.contains(dev)) {
                    print("Resource added: %s\n", dev);
                    var rs = nrs(dev);
                    buttonBox.append(rs.btn);
                    stack.add_child(rs.stackPage);
                    rs.btn.clicked.connect(() => stack.set_visible_child(rs.stackPage));
                    deviceMap.set(dev, rs);
                }
            }
            var toRemove = Utils.iteratorToArray<string>(deviceMap.keys.filter((dev) => !(dev in devices)));
            foreach (var disk in toRemove) {
                print("Resource removed: %s\n", disk);
                buttonBox.remove(deviceMap.get(disk).btn);
                stack.remove(deviceMap.get(disk).stackPage);
                deviceMap.unset(disk);
            }
            foreach (var dev in deviceMap.keys)
                deviceMap.get(dev).update();
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

    struct CPUStats {
        long cpuUser;
        long cpuNice;
        long cpuSystem;
        long cpuTotalTime;
        long prevCpuTime;
        float cpuUtil;

        public void update(string line, int num_cpus) {
            var split = Utils.splitStr(line, " ");
            cpuUser = long.parse(split[1]);
            cpuNice = long.parse(split[2]);
            cpuSystem = long.parse(split[3]);
            cpuTotalTime = cpuUser + cpuNice + cpuSystem;
            if (prevCpuTime == 0)
                prevCpuTime = cpuTotalTime;
            cpuUtil = (float)(cpuTotalTime - prevCpuTime) / ProcessWatcher.CLK_TCK / num_cpus;
            prevCpuTime = cpuTotalTime;
        }
    }

    abstract class ResourceStats {
        public ChartButton btn;
        public Gtk.Widget stackPage;

        public abstract void update();
    }

    class DiskStats : ResourceStats {
        public const int SECTOR_SIZE = 512; // UNIX sector, not specific to HW (size in bytes)
        
        public string Device;
        public string Model;

        public long io_ticks;
        long last_io_ticks = 0;
        public float active_pct;
        public long read_sectors;
        public long write_sectors;
        long last_read_sectors = 0;
        long last_write_sectors = 0;
        public float read_speed;
        public float write_speed;
        public long sum_ticks;
        public long sum_ios;
        long last_sum_ticks = 0;
        long last_sum_ios = 0;
        public float response_time;

        public DiskPage page;

        public DiskStats(string device) {
            Device = device;
            Model = (Utils.readFile("/sys/block/" + Device + "/device/vendor") ?? "").strip() + " " +
                    (Utils.readFile("/sys/block/" + Device + "/device/model") ?? "").strip();

            btn = new ChartButton();
            btn.chart.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            btn.chart.ChartColor = {0.96f, 0.74f, 0.18f, 1.0f};
            btn.chart.ChartFill = {0.96f, 0.74f, 0.18f, 0.5f};
            btn.Title = _("Disk (%s)").printf(Device);

            page = new DiskPage();
            page.lblDiskModel.label = Model;
            page.lblTitle.label = btn.Title;
            page.chart.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            page.chartSpeed.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            page.chartSpeed.DataPoints2 = new float[ResourceWatcher.ChartHistoryLength];
            page.init(Device);
            var scrolled = new Gtk.ScrolledWindow();
            scrolled.set_child(page);
            stackPage = scrolled;
        }

        public override void update() {
            string res;
            try {
                GLib.FileUtils.get_contents("/sys/block/" + Device + "/stat", out res);
                var stats = Utils.splitStr(res, " ");
                io_ticks = long.parse(stats[9], 10); // In milliseconds
                read_sectors = long.parse(stats[2]);
                write_sectors = long.parse(stats[6]);
                sum_ios = long.parse(stats[0]) + long.parse(stats[4]) + long.parse(stats[11]) + long.parse(stats[15]);
                sum_ticks = long.parse(stats[3]) + long.parse(stats[7]) + long.parse(stats[14]) + long.parse(stats[16]);
            } catch (FileError e) {
                print("Could not read disk stats: %s\n", e.message);
            }
            if (last_io_ticks == 0) last_io_ticks = io_ticks;
            if (last_read_sectors == 0) last_read_sectors = read_sectors;
            if (last_write_sectors == 0) last_write_sectors = write_sectors;
            if (last_sum_ios == 0) last_sum_ios = sum_ios;
            if (last_sum_ticks == 0) last_sum_ticks = sum_ticks;
            active_pct = (float)(io_ticks - last_io_ticks) / ResourceWatcher.UPDATE_INTERVAL;
            read_speed = SECTOR_SIZE * (float)(read_sectors - last_read_sectors) / (ResourceWatcher.UPDATE_INTERVAL / 1000.0f);
            write_speed = SECTOR_SIZE * (float)(write_sectors - last_write_sectors) / (ResourceWatcher.UPDATE_INTERVAL / 1000.0f);
            long handled_ios = sum_ios - last_sum_ios;
            if (handled_ios == 0)
                response_time = 0;
            else
                response_time = (float)(sum_ticks - last_sum_ticks) / handled_ios; // miliseconds
            
            btn.Status = "%s\n%.1f %%".printf(Model, active_pct*100.0f);
            btn.chart.push_value(active_pct);
            page.chart.push_value(active_pct);
            page.chartSpeed.DataPoints2[page.chartSpeed.DataStart] = write_speed;
            page.chartSpeed.push_value(read_speed);
            page.lblMaxSpeed.label = _("Max: %s/s".printf(Utils.humanSize(page.chartSpeed.MaxValue/1024, 1)));
            page.lblActiveTime.label = "%.1f %%".printf(active_pct*100.0f);
            page.lblReadSpeed.label = _("%s/s").printf(Utils.humanSize(read_speed/1024, 1));
            page.lblWriteSpeed.label = _("%s/s").printf(Utils.humanSize(write_speed/1024, 1));
            page.lblTotalRead.label = Utils.humanSize(read_sectors/2, 2, 3);
            page.lblTotalWrite.label = Utils.humanSize(write_sectors/2, 2, 3);
            page.lblResponseTime.label = _("%.2f ms").printf(response_time);

            last_io_ticks = io_ticks;
            last_read_sectors = read_sectors;
            last_write_sectors = write_sectors;
            last_sum_ios = sum_ios;
            last_sum_ticks = sum_ticks;
        }
    }

    class NetStats : ResourceStats {
        public string ifname;
        public string adapter = "";
        
        long rx_bytes;
        long last_rx_bytes;
        long tx_bytes;
        long last_tx_bytes;

        public float rx_speed;
        public float tx_speed;

        public NetworkPage page;

        public NetStats(string iface) {
            ifname = iface;
            var c = new GUdev.Client(null);
            var d = c.query_by_sysfs_path("/sys/class/net/" + ifname);
            if (d != null)
                adapter = d.get_property("ID_VENDOR_FROM_DATABASE") + " " + d.get_property("ID_MODEL_FROM_DATABASE");
            
            btn = new ChartButton();
            btn.chart.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            btn.chart.ChartColor = {0.12f, 0.88f, 0.3f, 1.0f};
            btn.chart.ChartFill = {0.12f, 0.88f, 0.3f, 0.5f};
            btn.chart.AutoScale = true;
            btn.Title = _("Network (%s)").printf(ifname);

            page = new NetworkPage();
            page.lblAdapter.label = adapter;
            page.lblTitle.label = btn.Title;
            page.chart.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            page.chart.ChartColor = {0.12f, 0.88f, 0.3f, 1.0f};
            page.chart.ChartFill = {0.12f, 0.88f, 0.3f, 0.5f};
            page.chart.AutoScale = true;
            stackPage = page;
        }

        public override void update() {
            string res;
            try {
                GLib.FileUtils.get_contents("/sys/class/net/" + ifname + "/statistics/rx_bytes", out res);
                rx_bytes = long.parse(res, 10);
                GLib.FileUtils.get_contents("/sys/class/net/" + ifname + "/statistics/tx_bytes", out res);
                tx_bytes = long.parse(res, 10);
            } catch (FileError e) {
                print("Could not read net stats: %s\n", e.message);
            }
            if (last_rx_bytes == 0) {
                last_rx_bytes = rx_bytes; last_tx_bytes = tx_bytes;
            }
            tx_speed = (tx_bytes - last_tx_bytes) / (1000.0f / ResourceWatcher.UPDATE_INTERVAL);
            rx_speed = (rx_bytes - last_rx_bytes) / (1000.0f / ResourceWatcher.UPDATE_INTERVAL);

            btn.Status = "↑ %s/s\n↓ %s/s".printf(Utils.humanSize(tx_speed/1024, 1, 2), 
                Utils.humanSize(rx_speed/1024, 1, 2));
            btn.chart.push_value(rx_speed); // TODO: Dual chart with tx_speed
            page.chart.push_value(rx_speed);

            last_rx_bytes = rx_bytes;
            last_tx_bytes = tx_bytes;
        }
    }
}