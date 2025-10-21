namespace Leaftop {
    class ResourceWatcher {
        public const int ChartHistoryLength = 60; // 60 s
        public const uint UPDATE_INTERVAL = 1000; //1 s

        ChartButton btnProcessor;
        ChartButton btnMemory;
        unowned ChartButton[] diskButtons;
        unowned ChartButton[] networkButtons;
        unowned ChartButton[] gpuButtons;

        private Gtk.Stack stack;
        private ProcessorPage pageProcessor;

        private long prevCpuTime = 0;

        public void init_switcher_buttons(Gtk.Box container) {
            btnProcessor = new ChartButton();
            btnProcessor.Title = _("Processor");
            btnProcessor.clicked.connect(() => stack.set_visible_child(pageProcessor));
            btnProcessor.chart.DataPoints = new float[ChartHistoryLength];
            container.append(btnProcessor);

            btnMemory = new ChartButton();
            btnMemory.chart.DataPoints = new float[ChartHistoryLength];
            btnMemory.Title = _("Memory");
            btnMemory.chart.ChartColor = {0.91f, 0.31f, 0.91f, 1.0f};
            btnMemory.chart.ChartFill = {0.91f, 0.31f, 0.91f, 0.5f};
            container.append(btnMemory);
        }

        public void init_stack_pages(Gtk.Stack _stack) {
            stack = _stack;

            pageProcessor = new ProcessorPage();
            pageProcessor.chart.DataPoints = new float[ChartHistoryLength];
            string res;
            try {
                GLib.FileUtils.get_contents("/proc/cpuinfo", out res);
            } catch (FileError e) {
                print("Could not read /proc/cpuinfo: %s\n", e.message);
                return;
            }
            pageProcessor.lblProcessorName.label = res.split("\n")[4].split(":")[1].strip();
            stack.add_child(pageProcessor);
        }

        public void start_watching() {
            Timeout.add(UPDATE_INTERVAL, update);
        }

        private bool update() {
            updateCPU();
            updateMemory();
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

            btnMemory.chart.push_value(memusage);
            btnMemory.Status = "%s / %s (%d %%)".printf(Utils.humanSize(totalmem - availmem, 1, 2), 
                Utils.humanSize(totalmem, 1, 2), (int)(memusage*100.0));
        }
    }
}