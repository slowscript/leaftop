namespace Leaftop {
    class ProcessWatcher {
        public const int UPDATE_INTERVAL = 2000;
        public static long CLK_TCK;

        const string[] CommonRoots = {"systemd", "cinnamon", "cinnamon-launcher", "cinnamon-session", "cinnamon-session-binary", "lightdm"};
        private ListStore listStore;
        public Gee.HashMap<int, ListStore> childStores = new Gee.HashMap<int, ListStore>();
        private Gee.HashMap<int, Process> processes;
        private Gee.HashMap<string, AppInfo> installedApps = new Gee.HashMap<string, AppInfo>();

        internal weak Gtk.Sorter mSorter;

        public ProcessWatcher(ListStore store) {
            listStore = store;
            CLK_TCK = Posix.sysconf(Posix._SC_CLK_TCK);
            var apps = AppInfo.get_all();
            foreach (AppInfo app in apps) {
                string exe = app.get_executable();
                string? id = app.get_id();
                if (id != null) {
                    if (id.has_suffix(".desktop"))
                        id = id[0:id.length-8];
                    installedApps.set(id, app);
                }
                if (exe != null && exe != "sh" && exe != "env")
                    installedApps.set(exe, app);
            }
        }

        public void startWatching() {
            // Load processes
            try {
                processes = loadAllProcesses();
            } catch (Error e) {
                printerr("Could not get processes: %s", e.message);
                return;
            }
            // Populate parent info
            List<Process> roots = new List<Process>();
            foreach (Process p in processes.values) {
                if (addProcessToTree(p))
                    roots.append(p);
            }
            // Only after we have parent info can proc be added to store
            foreach (Process p in roots) {
                p.updateTreeUtil();
                listStore.append(p);
            }
            Timeout.add(UPDATE_INTERVAL, update);
        }

        private List<int> loadAllPIDs() throws Error {
            List<int> pids = new List<int>();
            File procdir = File.new_for_path("/proc");
            var enumerator = procdir.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
            FileInfo info = null;
            while ((info = enumerator.next_file()) != null) {
                int pid = -1;
                if (info.get_file_type() == FileType.DIRECTORY && int.try_parse(info.get_name(), out pid)) {
                    pids.append(pid);
                }
            }
            return pids;
        }

        private Gee.HashMap<int, Process> loadAllProcesses() throws Error {
            Gee.HashMap<int, Process> ps = new Gee.HashMap<int, Process>();
            foreach (int pid in loadAllPIDs()) {
                var proc = new Process(pid);
                proc.Icon = get_icon(proc);
                ps.set(pid, proc);
            }
            return ps;
        }

        private bool addProcessToTree(Process p) {
            bool isRoot = false;
            if (p.ParentID in processes.keys) {
                Process parent = processes[p.ParentID];
                if (parent.Name in CommonRoots) {
                    p.Parent = null;
                    isRoot = true;
                } else {
                    p.Parent = parent;
                    parent.Children.add(p);
                }
            } else {
                p.Parent = null;
                isRoot = true;
            }
            return isRoot;
        }

        private Icon get_icon(Process p) {
            AppInfo app = installedApps.get(p.FlatpakID);
            if (app != null) {
                return app.get_icon();
            }
            app = installedApps.get(p.ExeName);
            if (app != null) {
                return app.get_icon();
            }
            app = installedApps.get(p.ExePath);
            if (app != null) {
                return app.get_icon();
            } 
            return new ThemedIcon("application-x-executable");
        }

        private bool update() {
            // Update known processes, remove ones that disappeared
            List<int> pidsRemoved = new List<int>();
            List<Process> newProcesses = new List<Process>();
            foreach (Process p in processes.values) {
                int knownParent = p.ParentID;
                if (!p.update()) {
                    //Process is gone
                    //print("Removed '%s' (%i), parent '%s'\n", p.Name, p.PID, p.Parent?.Name);
                    ListStore store = p.Parent == null ? listStore : childStores.get(p.ParentID);
                    // Remove from store
                    if (store != null) {
                        uint pos;
                        if (store.find(p, out pos))
                            store.remove(pos);
                    }
                    // Remove own store
                    childStores.unset(p.PID);
                    // Remove from children
                    if (p.Parent != null)
                        p.Parent.Children.remove(p);
                    // Finally, remove from processes dict
                    pidsRemoved.append(p.PID);
                } else {
                    if (p.ParentID != knownParent) {
                        print("%i (%s) was reparented from %i to %i\n", p.PID, p.Name, knownParent, p.ParentID);
                        if (knownParent != 0)
                            processes[knownParent].Children.remove(p);
                        // Remove from store
                        ListStore store = p.ParentID == 0 ? listStore : childStores.get(p.ParentID);
                        if (store != null) {
                            uint pos;
                            if (store.find(p, out pos))
                                store.remove(pos);
                        }
                        // Will add back to tree later
                        newProcesses.append(p);
                    }
                }
            }
            foreach (int pid in pidsRemoved) {
                processes.unset(pid);
            }
            try {
                foreach (int pid in loadAllPIDs()) {
                    if (!(pid in processes.keys)) {
                        var proc = new Process(pid);
                        proc.Icon = get_icon(proc);
                        processes.set(proc.PID, proc);
                        newProcesses.append(proc);
                        //print("New process '%s' (%i)\n", proc.Name, proc.PID);
                    }
                }
                // Populate parent info
                foreach (Process p in newProcesses) {
                    addProcessToTree(p);
                }
                // Add to store
                foreach (Process p in newProcesses) {
                    if (p.Parent != null) {
                        var store = childStores.get(p.ParentID);
                        if (store != null)
                            store.append(p);
                    } else listStore.append(p);
                }
            } catch (Error e) {
                printerr("Could not update process list: %s", e.message);
            }
            for (int i = 0; i < listStore.n_items; i++) {
                Process p = (Process)listStore.get_item(i);
                p.updateTreeUtil();
            }
            if (mSorter != null)
                mSorter.changed(Gtk.SorterChange.DIFFERENT); //Force re-sorting
            return true;
        }
    }
}
