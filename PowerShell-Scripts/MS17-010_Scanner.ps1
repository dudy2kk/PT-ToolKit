function MS17-010_Scanner{

    param(
        [String]
        $target
    )
$Source = @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
namespace PingCastle.Scanners
{
	public class ms17_010scanner
	{
		static public bool ScanForMs17_010(string computer)
		{
			Trace.WriteLine("Checking " + computer + " for MS17-010");
			TcpClient client = new TcpClient();
			client.Connect(computer, 445);
			try
			{
				NetworkStream stream = client.GetStream();
				byte[] negotiatemessage = GetNegotiateMessage();
				stream.Write(negotiatemessage, 0, negotiatemessage.Length);
				stream.Flush();
				byte[] response = ReadSmbResponse(stream);
				if (!(response[8] == 0x72 && response[9] == 00))
				{
					throw new InvalidOperationException("invalid negotiate response");
				}
				byte[] sessionSetup = GetSessionSetupAndXRequest(response);
				stream.Write(sessionSetup, 0, sessionSetup.Length);
				stream.Flush();
				response = ReadSmbResponse(stream);
				if (!(response[8] == 0x73 && response[9] == 00))
				{
					throw new InvalidOperationException("invalid sessionSetup response");
				}
				byte[] treeconnect = GetTreeConnectAndXRequest(response, computer);
				stream.Write(treeconnect, 0, treeconnect.Length);
				stream.Flush();
				response = ReadSmbResponse(stream);
				if (!(response[8] == 0x75 && response[9] == 00))
				{
					throw new InvalidOperationException("invalid TreeConnect response");
				}
				byte[] peeknamedpipe = GetPeekNamedPipe(response);
				stream.Write(peeknamedpipe, 0, peeknamedpipe.Length);
				stream.Flush();
				response = ReadSmbResponse(stream);
				if (response[8] == 0x25 && response[9] == 0x05 && response[10] ==0x02 && response[11] ==0x00 && response[12] ==0xc0 )
				{
					return true;
				}
			}
			catch (Exception)
			{
				throw;
			}
			return false;
		}
		private static byte[] ReadSmbResponse(NetworkStream stream)
		{
			byte[] temp = new byte[4];
			stream.Read(temp, 0, 4);
			int size = temp[3] + temp[2] * 0x100 + temp[3] * 0x10000;
			byte[] output = new byte[size + 4];
			stream.Read(output, 4, size);
			Array.Copy(temp, output, 4);
			return output;
		}
		static byte[] GetNegotiateMessage()
		{
			byte[] output = new byte[] {
				0x00,0x00,0x00,0x00, // Session Message
				0xff,0x53,0x4d,0x42, // Server Component: SMB
				0x72, // SMB Command: Negotiate Protocol (0x72)
				0x00, // Error Class: Success (0x00)
				0x00, // Reserved
				0x00,0x00, // Error Code: No Error
				0x18, // Flags
				0x01,0x28, // Flags 2
				0x00,0x00, // Process ID High 0
				0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // Signature
				0x00,0x00, // Reserved
				0x00,0x00, // Tree id 0
				0x44,0x6d, // Process ID 27972
				0x00,0x00, // User ID 0
				0x42,0xc1, // Multiplex ID 49474
				0x00, // WCT 0
				0x31,0x00, // BCC 49
				0x02,0x4c,0x41,0x4e,0x4d,0x41,0x4e,0x31,0x2e,0x30,0x00, // LANMAN1.0
				0x02,0x4c,0x4d,0x31,0x2e,0x32,0x58,0x30,0x30,0x32,0x00, // LM1.2X002
				0x02,0x4e,0x54,0x20,0x4c,0x41,0x4e,0x4d,0x41,0x4e,0x20,0x31,0x2e,0x30,0x00, // NT LANMAN 1.0
				0x02,0x4e,0x54,0x20,0x4c,0x4d,0x20,0x30,0x2e,0x31,0x32,0x00, // NT LM 0.12
			};
			return EncodeNetBiosLength(output);
		}
		static byte[] GetSessionSetupAndXRequest(byte[] data)
		{
			byte[] output = new byte[] {
				0x00,0x00,0x00,0x00, // Session Message
				0xff,0x53,0x4d,0x42, // Server Component: SMB
				0x73, // SMB Command: Session Setup AndX (0x73)
				0x00, // Error Class: Success (0x00)
				0x00, // Reserved
				0x00,0x00, // Error Code: No Error
				0x18, // Flags
				0x01,0x28, // Flags 2
				0x00,0x00, // Process ID High 0
				0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // Signature
				0x00,0x00, // Reserved
				data[28],data[29],data[30],data[31],data[32],data[33],
				0x42,0xc1, // Multiplex ID 49474
				0x0d, // WCT 0
				0xff, // AndXCommand: No further commands (0xff)
				0x00, // Reserved 00
				0x00,0x00, // AndXOffset: 0
				0xdf,0xff, // Max Buffer: 65503
				0x02,0x00, // Max Mpx Count: 2
				0x01,0x00, // VC Number: 1
				0x00,0x00,0x00,0x00, // Session Key: 0x00000000
				0x00,0x00, // ANSI Password Length: 0
				0x00,0x00, // Unicode Password Length: 0
				0x00,0x00,0x00,0x00, // Reserved: 00000000
				0x40,0x00,0x00,0x00, // Capabilities: 0x00000040, NT Status Codes
				0x26,0x00, // Byte Count (BCC): 38
				0x00, // Account:
				0x2e,0x00, // Primary Domain: .
				0x57,0x69,0x6e,0x64,0x6f,0x77,0x73,0x20,0x32,0x30,0x30,0x30,0x20,0x32,0x31,0x39,0x35,0x00, // Native OS: Windows 2000 2195
				0x57,0x69,0x6e,0x64,0x6f,0x77,0x73,0x20,0x32,0x30,0x30,0x30,0x20,0x35,0x2e,0x30,0x00 // Native LAN Manager: Windows 2000 5.0
			};
			return EncodeNetBiosLength(output);
		}
		private static byte[] EncodeNetBiosLength(byte[] input)
		{
			byte[] len = BitConverter.GetBytes(input.Length-4);
			input[3] = len[0];
			input[2] = len[1];
			input[1] = len[2];
			return input;
		}
		static byte[] GetTreeConnectAndXRequest(byte[] data, string computer)
		{
			MemoryStream ms = new MemoryStream();
			BinaryReader reader = new BinaryReader(ms);
			byte[] part1 = new byte[] {
				0x00,0x00,0x00,0x00, // Session Message
				0xff,0x53,0x4d,0x42, // Server Component: SMB
				0x75, // SMB Command: Tree Connect AndX (0x75)
				0x00, // Error Class: Success (0x00)
				0x00, // Reserved
				0x00,0x00, // Error Code: No Error
				0x18, // Flags
				0x01,0x28, // Flags 2
				0x00,0x00, // Process ID High 0
				0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // Signature
				0x00,0x00, // Reserved
				data[28],data[29],data[30],data[31],data[32],data[33],
				0x42,0xc1, // Multiplex ID 49474
				0x04, // WCT 4
				0xff, // AndXCommand: No further commands (0xff)
				0x00, // Reserved: 00
				0x00,0x00, // AndXOffset: 0
				0x00,0x00, // Flags: 0x0000
				0x01,0x00, // Password Length: 1
				0x19,0x00, // Byte Count (BCC): 25
				0x00, // Password: 00
				0x5c,0x5c};
			byte[] part2 = new byte[] {
				0x5c,0x49,0x50,0x43,0x24,0x00, // Path: \\ip_target\IPC$
				0x3f,0x3f,0x3f,0x3f,0x3f,0x00
			};
			ms.Write(part1, 0, part1.Length);
			byte[] encodedcomputer = new ASCIIEncoding().GetBytes(computer);
			ms.Write(encodedcomputer, 0, encodedcomputer.Length);
			ms.Write(part2, 0, part2.Length);
			ms.Seek(0, SeekOrigin.Begin);
			byte[] output = reader.ReadBytes((int) reader.BaseStream.Length);
			return EncodeNetBiosLength(output);
		}
		static byte[] GetPeekNamedPipe(byte[] data)
		{
			byte[] output = new byte[] {
				0x00,0x00,0x00,0x00, // Session Message
				0xff,0x53,0x4d,0x42, // Server Component: SMB
				0x25, // SMB Command: Trans (0x25)
				0x00, // Error Class: Success (0x00)
				0x00, // Reserved
				0x00,0x00, // Error Code: No Error
				0x18, // Flags
				0x01,0x28, // Flags 2
				0x00,0x00, // Process ID High 0
				0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // Signature
				0x00,0x00, // Reserved
				data[28],data[29],data[30],data[31],data[32],data[33],
				0x42,0xc1, // Multiplex ID 49474
				0x10, // Word Count (WCT): 16
				0x00,0x00, // Total Parameter Count: 0
				0x00,0x00, // Total Data Count: 0
				0xff,0xff, // Max Parameter Count: 65535
				0xff,0xff, // Max Data Count: 65535
				0x00, // Max Setup Count: 0
				0x00, // Reserved: 00
				0x00,0x00, // Flags: 0x0000
				0x00,0x00,0x00,0x00, // Timeout: Return immediately (0)
				0x00,0x00, // Reserved: 0000
				0x00,0x00, // Parameter Count: 0
				0x4a,0x00, // Parameter Offset: 74
				0x00,0x00, // Data Count: 0
				0x4a,0x00, // Data Offset: 74
				0x02, // Setup Count: 2
				0x00, // Reserved: 00
				0x23,0x00, // Function: PeekNamedPipe (0x0023)
				0x00,0x00, // FID: 0x0000
				0x07,0x00, // Byte Count (BCC): 7
				0x5c,0x50,0x49,0x50,0x45,0x5c,0x00 // Transaction Name: \PIPE\
			};
			return EncodeNetBiosLength(output);
		}
	}
}
"@
Add-Type -TypeDefinition $Source

[PingCastle.Scanners.ms17_010scanner]::ScanForMs17_010("$target")
}
