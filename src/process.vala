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
        public float CpuTreeUtil { get; private set; }
        public string CpuUtilStr { get; private set; }
        public float DiskUtil { get; private set; }
        public float DiskTreeUtil { get; private set; }
        public string DiskUtilStr { get; private set; }
        public bool expanded = false;

        private string[] status;
        private string? rssAnon;
        private long prevCpuTime = 0;
        private long prevDiskRW = 0;

        public Process(int pid) {
            PID = pid;
            CmdLine = readProcFile("cmdline");
            if (CmdLine != null) {
                // FIXME: Arguments are behind \0, but they are not read correctly
                var exePath = CmdLine/*.split("\0")[0]*/.split("/");
                if (exePath.length > 0) {
                    ExeName = exePath[exePath.length-1];
                } else ExeName = "";
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
            if (n == "bwrap" && Parent == null && Children.size > 0)
                this.Name = n + " (" + Children.get(0)?.getBwrapName() + ")";
            else
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
            prevCpuTime = cpuTime;
            long disk = getDiskRWTotal();
            long diskDif = disk - prevDiskRW;
            DiskUtil = diskDif / (ProcessWatcher.UPDATE_INTERVAL / 1000.0f);
            prevDiskRW = disk;
            return true;
        }

        public void updateTreeUtil() {
            int treeMem = this.MemUsage;
            float treeCpu = this.CpuUtil;
            float treeDisk = this.DiskUtil;
            foreach (Process c in Children) {
                c.updateTreeUtil();
                treeMem += c.MemTreeUsage;
                treeCpu += c.CpuTreeUtil;
                treeDisk += c.DiskTreeUtil;
            }
            this.MemTreeUsage = treeMem;
            this.CpuTreeUtil = treeCpu;
            this.DiskTreeUtil = treeDisk;
            if (Parent == null && Children.size > 0) {
                this.MemString = rssAnon != null ? "<small>%s</small>\n<span size=\"x-small\">%s</span>"
                    .printf(Utils.humanSize(MemTreeUsage), Utils.humanSize(MemUsage))
                    : "N/A";
                this.CpuUtilStr = "<small>%.1f</small>\n<span size=\"x-small\">%.1f</span>".printf(CpuTreeUtil, CpuUtil);
                this.DiskUtilStr = @"<small>$(Utils.humanSize(DiskTreeUtil / 1000.0f))/s</small>\n<span size=\"x-small\">$(Utils.humanSize(DiskUtil / 1000.0f))/s</span>";
            } else {
                this.MemString = rssAnon != null ? @"<small>$(Utils.humanSize(MemUsage))</small>" : "N/A";
                this.CpuUtilStr = "%.1f".printf(CpuUtil);
                this.DiskUtilStr = "<small>" + Utils.humanSize(DiskUtil / 1000.0f) + "/s</small>";
            }
        }

        private string getBwrapName() {
            if (Children.size > 0) {
                var c0 = Children[0];
                if (c0.Name == "bwrap")
                    return c0.getBwrapName();
                else
                    return c0.Name;
            } else
                return Name;
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