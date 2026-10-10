// Unsigned payloads used only by windows_installer_migration_smoke.ps1.
// This executable is never packaged by a Lantern release build.
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.ServiceProcess;

#if LEGACY
[assembly: AssemblyVersion("7.9.5.0")]
#else
[assembly: AssemblyVersion("10.0.0.0")]
#endif

class Fixture
{
    const string ServiceName = "LanternInstallerMigrationFixtureSvc";

    static int Main(string[] args)
    {
#if DEPENDENCY
        string marker = Environment.GetEnvironmentVariable("LANTERN_FIXTURE_DEPENDENCY_MARKER");
        if (!String.IsNullOrEmpty(marker)) File.AppendAllText(marker, "prerequisite executed\n");
        int exitCode;
        return Int32.TryParse(Environment.GetEnvironmentVariable("LANTERN_FIXTURE_DEPENDENCY_EXIT_CODE"), out exitCode) ? exitCode : 0;
#elif APP
        string marker = Environment.GetEnvironmentVariable("LANTERN_FIXTURE_UI_MARKER");
        if (!String.IsNullOrEmpty(marker)) File.AppendAllText(marker, "app launched\n");
        if (args.Length > 0 && args[0] == "--hold") System.Threading.Thread.Sleep(300000);
        return 0;
#else
        if (args.Length > 0 && args[0] == "prepare-legacy-migration")
        {
            if (args.Length != 7 || args[1] != "--sid" || args[3] != "--source" || args[5] != "--migration-id") return 45;
            var sid = new System.Security.Principal.SecurityIdentifier(args[2]);
            if (!File.Exists(Path.Combine(args[4], "lantern.exe")) || args[6].Length != 32) return 46;
            string folder = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            string mode = File.ReadAllText(Path.Combine(folder, "fixture-service-mode.txt")).Trim();
            if (mode == "prepare-fail") return 47;
            File.WriteAllText(Path.Combine(folder, "fixture-enrollment.json"), "{\"sid\":\"" + sid.Value + "\",\"migration_id\":\"" + args[6] + "\"}");
            return 0;
        }
        if (args.Length > 0 && args[0] == "install")
        {
            string executable = Assembly.GetExecutingAssembly().Location;
            if (!File.Exists(Path.Combine(Path.GetDirectoryName(executable), "fixture-enrollment.json"))) return 48;
            string mode = File.ReadAllText(Path.Combine(Path.GetDirectoryName(executable), "fixture-service-mode.txt")).Trim();
            int result = Sc("create " + ServiceName + " binPath= \"\\\"" + executable + "\\\"\" start= demand");
            if (result != 0) return result;
            if (mode == "create-and-fail") return 42;
            if (mode == "leave-stopped") return 0;
            if (mode != "running") return 43;
            result = Sc("start " + ServiceName);
            if (result != 0) return result;
            using (var controller = new ServiceController(ServiceName))
                controller.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(15));
            return 0;
        }
        if (args.Length > 0 && args[0] == "uninstall")
        {
            Sc("stop " + ServiceName);
            Sc("delete " + ServiceName);
            return 0;
        }
        ServiceBase.Run(new FixtureService());
        return 0;
#endif
    }

    static int Sc(string arguments)
    {
        using (var process = Process.Start(new ProcessStartInfo("sc.exe", arguments) {
            UseShellExecute = false,
            CreateNoWindow = true
        }))
        {
            if (!process.WaitForExit(15000)) { process.Kill(); return 44; }
            return process.ExitCode;
        }
    }

    sealed class FixtureService : ServiceBase
    {
        public FixtureService() { ServiceName = Fixture.ServiceName; }
        protected override void OnStart(string[] args) { }
        protected override void OnStop() { }
    }
}
