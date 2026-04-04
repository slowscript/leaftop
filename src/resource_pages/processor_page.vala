namespace Leaftop {
    [GtkTemplate (ui = "/xyz/slowscript/leaftop/resource_pages/processor_page.ui")]
    class ProcessorPage : Gtk.Box {
        [GtkChild]
        public unowned ChartWidget singleChart;
        [GtkChild]
        public unowned Gtk.Grid chartGrid;
        [GtkChild]
        public unowned Gtk.Stack chartStack;
        [GtkChild]
        public unowned Gtk.Label lblProcessorName;
        
        public ChartWidget[] cpuCharts;

        private DetailsGrid details = new DetailsGrid();
        public Gtk.Label lblUsage;
        public Gtk.Label lblFrequency;
        public Gtk.Label lblProcesses;
        public Gtk.Label lblThreads;
        public Gtk.Label lblDescriptors;
        public Gtk.Label lblUptime;

        construct {
            singleChart.DataPoints = new float[ResourceWatcher.ChartHistoryLength];
            
            var leftClickController = new Gtk.GestureClick();
            leftClickController.button = 3;
            leftClickController.pressed.connect((n, x, y) => {
                chartStack.set_visible_child_name(chartStack.get_visible_child_name() == "page_total" ? "page_logical" : "page_total");
            });
            chartStack.add_controller(leftClickController);

            append(details.grid);
            lblUsage = details.add_row(_("Usage:"));
            lblFrequency = details.add_row(_("Frequency:"));
            lblProcesses = details.add_row(_("Processes:"));
            lblThreads = details.add_row(_("Threads:"));
            lblDescriptors = details.add_row(_("Descriptors:"));
            lblUptime = details.add_row(_("Uptime:"));
        }

        public void init(int numCPUs) {

            int numCols = (int)Math.ceil(Math.sqrt(numCPUs));
            int numRows = (int)Math.ceil((double)numCPUs / numCols);
            cpuCharts = new ChartWidget[numCPUs];
            for (int i = 0; i < numCPUs; i++) {
                cpuCharts[i] = new ChartWidget();
                cpuCharts[i].DataPoints = new float[ResourceWatcher.ChartHistoryLength];
                cpuCharts[i].hexpand = true;
                cpuCharts[i].height_request = 250 / numRows;
                chartGrid.attach(cpuCharts[i], i % numCols, i / numCols);
            }
            string cpuinfo = Utils.readFile("/proc/cpuinfo");
            lblProcessorName.label = cpuinfo.split("\n")[4].split(":")[1].strip();

            // Second column (static info)
            details.add_column();
            // Base and max clock
            string baseclock = Utils.readFile("/sys/devices/system/cpu/cpufreq/policy0/base_frequency") ?? "-";
            details.add_row(_("Base clock:"), baseclock[0].isdigit() ? "%.2f GHz".printf(int.parse(baseclock)/1000000.0f) : baseclock);
            string maxclock = Utils.readFile("/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq");
            details.add_row(_("Max clock:"), "%.2f GHz".printf(int.parse(maxclock)/1000000.0f));
            // Topology
            CPUTopo.read();
            details.add_row(_("Sockets:"), CPUTopo.packages.to_string("%d"));
            details.add_row(_("Dies:"), CPUTopo.dies.to_string("%d"));
            details.add_row(_("Cores:"), CPUTopo.cores.to_string("%d"));
            details.add_row(_("Threads:"), CPUTopo.threads.to_string("%d"));
            // Cache
            details.add_column();
            var caches = new Gee.ArrayList<CPUCache>();
            caches.add_all(CPUTopo.caches.values);
            caches.sort((a, b) => {
                return strcmp(a.type, b.type);
            });
            foreach (CPUCache c in caches) {
                details.add_row(_("Cache %s:".printf(c.type)),
                    _("%s %s-way %s sets").printf(Utils.humanSize(c.size/1024, 0), c.associativity, c.sets));
            }
        }
    }

    class CPUCache {
        public string type;
        public int size;
        public string associativity;
        public string sets;
        private Gee.ArrayList<string> ids;

        public CPUCache(string label, string cpu, string name) {
            ids = new Gee.ArrayList<string>();
            type = label;
            size = 0;
            add_size(cpu, name);
            associativity = Utils.readFile("/sys/devices/system/cpu/%s/cache/%s/ways_of_associativity".printf(cpu, name)).strip();
            sets = Utils.readFile("/sys/devices/system/cpu/%s/cache/%s/number_of_sets".printf(cpu, name)).strip();
        }

        public static string get_cache_type(string cpu, string name) {
            string level = Utils.readFile("/sys/devices/system/cpu/%s/cache/%s/level".printf(cpu, name)).strip();
            string t = Utils.readFile("/sys/devices/system/cpu/%s/cache/%s/type".printf(cpu, name)).strip();
            if (t == "Data")
                return "L%sd".printf(level);
            else if (t == "Instruction")
                return "L%si".printf(level);
            else
                return "L%s".printf(level);
        }
        
        public void add_size(string cpu, string name) {
            string id = Utils.readFile("/sys/devices/system/cpu/%s/cache/%s/id".printf(cpu, name));
            if (!(id in ids)) {
                ids.add(id);
                size += Utils.parse_suffix(Utils.readFile("/sys/devices/system/cpu/%s/cache/%s/size".printf(cpu, name)));
            }
        }
    }

    class CPUTopo {
        public static int threads;
        public static int cores;
        public static int dies;
        public static int packages;
        public static Gee.HashMap<string, CPUCache> caches;

        public static void read() {
            var dir = File.new_for_path("/sys/devices/system/cpu");
            Gee.ArrayList<string> cpus = new Gee.ArrayList<string>();
            try {
                var children = dir.enumerate_children("standard::*", GLib.FileQueryInfoFlags.NONE);
                FileInfo fi;
                while ((fi = children.next_file()) != null) {
                    var name = fi.get_name();
                    if (!Regex.match_simple("cpu\\d+", name)) continue;
                    cpus.add(name);
                }
            } catch (Error e) {
                printerr("Could not enumerate CPUs for topology: %s\n", e.message);
            }
            threads = cpus.size;
            var core_ids = new Gee.TreeSet<string>();
            var die_ids = new Gee.TreeSet<string>();
            var package_ids = new Gee.TreeSet<string>();
            caches = new Gee.HashMap<string, CPUCache>();
            foreach (string cpu in cpus) {
                string package = Utils.readFile("/sys/devices/system/cpu/%s/topology/physical_package_id".printf(cpu));
                package_ids.add(package);
                string die = Utils.readFile("/sys/devices/system/cpu/%s/topology/die_id".printf(cpu));
                die_ids.add(die);
                string core = Utils.readFile("/sys/devices/system/cpu/%s/topology/core_id".printf(cpu));
                core_ids.add(core);
                // Cache
                try {
                    foreach (FileInfo fi in Utils.enumerate_dir("/sys/devices/system/cpu/%s/cache".printf(cpu))) {
                        if (fi.get_file_type() != FileType.DIRECTORY) continue;
                        string name = fi.get_name();
                        string cache_lbl = CPUCache.get_cache_type(cpu, name);
                        if (caches.has_key(cache_lbl))
                            caches[cache_lbl].add_size(cpu, name);
                        else {
                            var cache = new CPUCache(cache_lbl, cpu, name);
                            caches.set(cache_lbl, cache);
                        }
                    }
                } catch (Error e) {
                    printerr("Could not enumerate CPU caches for %s: %s\n", cpu, e.message);
                }
            }
            cores = core_ids.size;
            dies = die_ids.size;
            packages = package_ids.size;
        }
    }
}