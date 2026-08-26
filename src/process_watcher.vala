namespace Leaftop {
    enum ProcessGrouping {
        SIMPLE, FLAT, TREE, CGROUP
    }
    const string[] ProcessGroupings = { "simple", "flat", "tree", "cgroups" };
    ProcessGrouping processGroupingFromString(string grouping) {
        ProcessGrouping g;
        if (grouping == "flat")
            g = ProcessGrouping.FLAT;
        else if (grouping == "tree")
            g = ProcessGrouping.TREE;
        else if (grouping == "cgroup")
            g = ProcessGrouping.CGROUP;
        else
            g = ProcessGrouping.SIMPLE;
        return g;
    }

    class ProcessWatcher {
        public const int UPDATE_INTERVAL = 2000;
        public static long CLK_TCK;

        string[] CommonRoots = {"systemd", "init", "dinit", "lightdm",
            "cinnamon", "cinnamon-launcher", "cinnamon-session", "cinnamon-session-binary",
            "gnome-shell", "xfce4-session", "xfce4-panel", "mate-session", "mate-panel", "lxsession", "lxpanel",
            "plasmashell", "lxqt-session" };
        private ListStore listStore;
        public Gee.HashMap<int, ListStore> childStores = new Gee.HashMap<int, ListStore>();
        public ProcessGrouping grouping = ProcessGrouping.SIMPLE;
        
        private Gee.HashMap<int, Process> processes;
        private Gee.HashMap<string, AppInfo> installedApps = new Gee.HashMap<string, AppInfo>();
        private Gtk.IconTheme installedIcons;

        public static int numProcesses = 0;
        public static int numThreads = 0;

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
            installedIcons = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
        }

        void initProcessLists() {
            // Load processes
            try {
                processes = loadAllProcesses();
            } catch (Error e) {
                printerr("Could not get processes: %s", e.message);
                return;
            }
            // Populate parent info
            Gee.LinkedList<Process> roots = new Gee.LinkedList<Process>();
            foreach (Process p in processes.values) {
                if (addProcessToTree(p))
                    roots.add(p);
            }
            // Only after we have parent info can proc be added to store
            foreach (Process p in roots) {
                p.updateTreeUtil();
            }
            listStore.splice(0, 0, roots.to_array());
        }

        public void startWatching() {
            initProcessLists();
            Timeout.add(UPDATE_INTERVAL, update);
        }

        public void setGrouping(ProcessGrouping _grouping) {
            grouping = _grouping;
            listStore.remove_all();
            initProcessLists();
        }

        public void ungroup_children_of(Process p) {
            if (grouping == ProcessGrouping.FLAT)
                return; // Do nothing, process grouping does not show children
            CommonRoots += p.Name;

            // Apply grouping (and switch to Simple if not already)
            setGrouping(ProcessGrouping.SIMPLE);
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
                if (grouping == ProcessGrouping.FLAT
                    || (grouping == ProcessGrouping.SIMPLE && parent.Name in CommonRoots)
                    || (grouping == ProcessGrouping.CGROUP && parent.CGroup != p.CGroup)) {
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
                var ico = app.get_icon();
                if (ico != null) return ico;
            }
            app = installedApps.get(p.ExeName);
            if (app != null) {
                var ico = app.get_icon();
                if (ico != null) return ico;
            }
            app = installedApps.get(p.CmdLine?[0]);
            if (app != null) {
                var ico = app.get_icon();
                if (ico != null) return ico;
            } 
            if (installedIcons.has_icon(p.Name))
                return new ThemedIcon(p.Name);
            app = installedApps.get(p.ExePath);
            if (app != null) {
                var ico = app.get_icon();
                if (ico != null) return ico;
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
            // Update tree from roots
            for (int i = 0; i < listStore.n_items; i++) {
                Process p = (Process)listStore.get_item(i);
                p.updateTreeUtil();
            }
            // Full tree pass
            int threads = 0;
            foreach (Process p in processes.values)
                threads += p.NumThreads;
            numProcesses = processes.size;
            numThreads = threads;
            if (mSorter != null)
                mSorter.changed(Gtk.SorterChange.DIFFERENT); //Force re-sorting
            return true;
        }
    }
}
