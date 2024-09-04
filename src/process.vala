namespace Leaftop {
    class Process : Object {

        public int PID { get; private set; }
        public int ParentID = 0; // 0 = no parent
        public weak Process? Parent = null;
        public Gee.ArrayList<weak Process> Children = new Gee.ArrayList<weak Process>();
        public string Name { get; private set; }
        public string CmdLine { get; private set; }
        public string ExeName { get; private set; }
        public Icon Icon { get; set; }
        public int MemUsage { get; private set; }
        public int MemTreeUsage { get; private set; }
        public string MemString { get; private set; }
        public float CpuUtil { get; private set; }
        public string CpuUtilStr { get; private set; }
        public float DiskUse { get; private set; }
        public string DiskUseStr { get; private set; }

        private string[] status;
        private string? rssAnon;
        private long prevCpuTime = 0;
        private long prevDiskRW = 0;

        public Process(int pid) {
            PID = pid;
            CmdLine = readProcFile("cmdline");
            // FIXME: Arguments are behind \0, but they are not read correctly
            var exePath = CmdLine/*.split("\0")[0]*/.split("/");
            if (exePath.length > 0) {
                ExeName = exePath[exePath.length-1];
            } else ExeName = "";
            prevCpuTime = getCpuTime();
            prevDiskRW = getDiskRWTotal();
            update();
        }

        public bool update() {
            string statstring = readProcFile("status");
            if (statstring == null)
                return false; // Process no longer exists
            this.status = statstring.split("\n");
            string n = getStatusValue("Name"); //readProcFile("comm");
            if (ExeName.has_prefix(n))
                n = ExeName;
            this.Name = n;
            this.ParentID = int.parse(getStatusValue("PPid"));
            this.rssAnon = getStatusValue("RssAnon");
            if (rssAnon != null)
                this.MemUsage = int.parse(rssAnon.split(" ")[0]);
            else
                this.MemUsage = 0;
            long cpuTime = getCpuTime();
            float utilTime = (cpuTime - prevCpuTime) / (float)ProcessWatcher.CLK_TCK;
            //TODO: get_num_processors reports only processors available to this process
            CpuUtil = utilTime / (ProcessWatcher.UPDATE_INTERVAL / 1000.0f) * 100.0f / get_num_processors();
            CpuUtilStr = "%.1f".printf(CpuUtil);
            prevCpuTime = cpuTime;
            long disk = getDiskRWTotal();
            long diskDif = disk - prevDiskRW;
            DiskUse = diskDif / (ProcessWatcher.UPDATE_INTERVAL / 1000.0f);
            DiskUseStr = Utils.humanSize(DiskUse / 1000.0f) + "/s";
            prevDiskRW = disk;
            return true;
        }

        public void updateTreeMem() {
            int treeMem = this.MemUsage;
            foreach (Process c in Children) {
                c.updateTreeMem();
                treeMem += c.MemTreeUsage;
            }
            this.MemTreeUsage = treeMem;
            if (rssAnon != null) {
                if (Parent == null && Children.size > 0)
                    this.MemString = @"<small><b>$(Utils.humanSize(MemTreeUsage))</b>\n$(Utils.humanSize(MemUsage))</small>";
                else
                    this.MemString = Utils.humanSize(MemUsage);
            } else {
                this.MemString = "N/A";
            }
        }

        public int getTreeMem() {
            int total = this.MemUsage;
            foreach (Process c in Children)
                total += c.getTreeMem();
            return total;
        }

        private long getCpuTime() {
            var stat = readProcFile("stat");
            if (stat == null)
                return 0;
            string s = stat.split(") ")[1];
            string[] s2 = s.split(" ");
            long ut = long.parse(s2[11], 10);
            long st = long.parse(s2[12], 10);
            return ut + st;
        }

        private long getDiskRWTotal() {
            var io = readProcFile("io");
            if (io == null)
                return 0;
            var lines = io.split("\n");
            long read = long.parse(lines[4].split(": ")[1], 10);
            long write = long.parse(lines[5].split(": ")[1], 10);
            return read + write;
        }

        private string? getStatusValue(string key) {
            string? line = null;
            foreach (string l in status) {
                if (l.has_prefix(key)) {
                    line = l;
                    break;
                }
            }
            if (line != null) {
                return line[line.index_of_char(':')+1:].strip();
            }
            return null;
        }

        private string? readProcFile(string file) {
            string path = GLib.Path.build_filename("/proc", PID.to_string(), file);
            string res = null;
            try {
                GLib.FileUtils.get_contents(path, out res);
                res = res.chomp();
            } catch (FileError err) {
                //print("Could not read %s: %s\n", path, err.message);
            }
            return res;
        }
    }
}