using Godot;
using System;
using System.Collections.Generic;
using System.IO.Ports;

public partial class CustomControllerSerial : Node
{
	private const byte SOF = 0xA5;
	private const byte CRC8_INIT = 0xFF;
	private const ushort CRC16_INIT = 0xFFFF;
	private const ushort CMD_ID_0302 = 0x0302;
	private const ushort CMD_ID_0309 = 0x0309;

	private SerialPort _serialPort = null;
	private string _portName = "/dev/ttyUSB0";
	private int _baudRate = 115200;
	private int _dataBits = 8;
	private StopBits _stopBits = StopBits.One;
	private Parity _parity = Parity.None;
	private int _maxRxBuffer = 4096;

	private byte _seq = 0;
	private readonly List<byte> _rxBuffer = new();
	private readonly Queue<byte[]> _frame0302Queue = new();
	private readonly Queue<byte[]> _txFrameQueueForTest = new();

	private int _crcErrorCount = 0;
	private int _ignoredFrameCount = 0;
	private bool _testMode = false;

	public override void _ExitTree()
	{
		ClosePort();
	}

	public bool Configure(string portName, int baudRate, int dataBits, int stopBits, string parity, int maxRxBuffer)
	{
		string normalizedPort = string.IsNullOrWhiteSpace(portName) ? "/dev/ttyUSB0" : portName.Trim();
		int normalizedBaud = Math.Max(1200, baudRate);
		int normalizedDataBits = Math.Clamp(dataBits, 5, 8);
		StopBits normalizedStopBits = ParseStopBits(stopBits);
		Parity normalizedParity = ParseParity(parity);
		int normalizedMaxRxBuffer = Math.Max(512, maxRxBuffer);

		bool changed = normalizedPort != _portName
			|| normalizedBaud != _baudRate
			|| normalizedDataBits != _dataBits
			|| normalizedStopBits != _stopBits
			|| normalizedParity != _parity
			|| normalizedMaxRxBuffer != _maxRxBuffer;

		_portName = normalizedPort;
		_baudRate = normalizedBaud;
		_dataBits = normalizedDataBits;
		_stopBits = normalizedStopBits;
		_parity = normalizedParity;
		_maxRxBuffer = normalizedMaxRxBuffer;

		if (changed && !_testMode && IsPortOpen())
		{
			ReopenPort();
		}

		return changed;
	}

	public void SetTestMode(bool enabled)
	{
		_testMode = enabled;
		if (_testMode)
		{
			ClosePort();
		}
	}

	public bool OpenPort()
	{
		if (_testMode)
		{
			return true;
		}

		if (IsPortOpen())
		{
			return true;
		}

		try
		{
			_serialPort = new SerialPort(_portName, _baudRate, _parity, _dataBits, _stopBits)
			{
				Handshake = Handshake.None,
				ReadTimeout = 20,
				WriteTimeout = 20
			};
			_serialPort.Open();
			return true;
		}
		catch
		{
			ClosePort();
			return false;
		}
	}

	public void ClosePort()
	{
		if (_serialPort == null)
		{
			return;
		}

		try
		{
			if (_serialPort.IsOpen)
			{
				_serialPort.Close();
			}
			_serialPort.Dispose();
		}
		catch
		{
			// Ignore close errors.
		}
		finally
		{
			_serialPort = null;
		}
	}

	public bool IsPortOpen()
	{
		if (_testMode)
		{
			return true;
		}
		return _serialPort != null && _serialPort.IsOpen;
	}

	public void ReopenPort()
	{
		ClosePort();
		OpenPort();
	}

	public bool Pump()
	{
		if (_testMode)
		{
			ParseFrames();
			return true;
		}

		if (!IsPortOpen())
		{
			return false;
		}

		try
		{
			while (_serialPort != null && _serialPort.IsOpen && _serialPort.BytesToRead > 0)
			{
				int chunkSize = Math.Min(_serialPort.BytesToRead, 4096);
				byte[] temp = new byte[chunkSize];
				int read = _serialPort.Read(temp, 0, chunkSize);
				if (read > 0)
				{
					AppendRxBytes(temp, read);
				}
				else
				{
					break;
				}
			}
			ParseFrames();
			return true;
		}
		catch
		{
			ClosePort();
			return false;
		}
	}

	public bool Send0309(byte[] payload)
	{
		if (payload == null || payload.Length != 30)
		{
			return false;
		}

		byte[] frame = BuildFrame(CMD_ID_0309, payload);
		if (_testMode)
		{
			_txFrameQueueForTest.Enqueue(frame);
			return true;
		}

		if (!IsPortOpen())
		{
			return false;
		}

		try
		{
			_serialPort.Write(frame, 0, frame.Length);
			return true;
		}
		catch
		{
			ClosePort();
			return false;
		}
	}

	public byte[] BuildFrame(ushort cmdId, byte[] payload)
	{
		byte[] data = payload ?? Array.Empty<byte>();
		int frameLength = 5 + 2 + data.Length + 2;
		byte[] frame = new byte[frameLength];

		frame[0] = SOF;
		frame[1] = (byte)(data.Length & 0xFF);
		frame[2] = (byte)((data.Length >> 8) & 0xFF);
		frame[3] = _seq++;
		frame[4] = GetCrc8(frame, 4, CRC8_INIT);

		frame[5] = (byte)(cmdId & 0xFF);
		frame[6] = (byte)((cmdId >> 8) & 0xFF);
		Buffer.BlockCopy(data, 0, frame, 7, data.Length);

		ushort crc16 = GetCrc16(frame, frameLength - 2, CRC16_INIT);
		frame[frameLength - 2] = (byte)(crc16 & 0xFF);
		frame[frameLength - 1] = (byte)((crc16 >> 8) & 0xFF);
		return frame;
	}

	public void InjectRxBytesForTest(byte[] data)
	{
		if (data == null || data.Length == 0)
		{
			return;
		}
		AppendRxBytes(data, data.Length);
		ParseFrames();
	}

	public Godot.Collections.Array<byte[]> DrainFrames0302()
	{
		var frames = new Godot.Collections.Array<byte[]>();
		while (_frame0302Queue.Count > 0)
		{
			frames.Add(_frame0302Queue.Dequeue());
		}
		return frames;
	}

	public int ConsumeCrcErrorCount()
	{
		int count = _crcErrorCount;
		_crcErrorCount = 0;
		return count;
	}

	public int ConsumeIgnoredFrameCount()
	{
		int count = _ignoredFrameCount;
		_ignoredFrameCount = 0;
		return count;
	}

	public Godot.Collections.Array<byte[]> DrainTxFramesForTest()
	{
		var frames = new Godot.Collections.Array<byte[]>();
		while (_txFrameQueueForTest.Count > 0)
		{
			frames.Add(_txFrameQueueForTest.Dequeue());
		}
		return frames;
	}

	private void AppendRxBytes(byte[] data, int count)
	{
		for (int i = 0; i < count; i++)
		{
			_rxBuffer.Add(data[i]);
		}
		int overflow = _rxBuffer.Count - _maxRxBuffer;
		if (overflow > 0)
		{
			_rxBuffer.RemoveRange(0, overflow);
		}
	}

	private void ParseFrames()
	{
		while (true)
		{
			int sofIndex = _rxBuffer.IndexOf(SOF);
			if (sofIndex < 0)
			{
				_rxBuffer.Clear();
				return;
			}

			if (sofIndex > 0)
			{
				_rxBuffer.RemoveRange(0, sofIndex);
			}

			if (_rxBuffer.Count < 5)
			{
				return;
			}

			byte[] header = _rxBuffer.GetRange(0, 5).ToArray();
			if (!VerifyCrc8(header))
			{
				_crcErrorCount += 1;
				_rxBuffer.RemoveAt(0);
				continue;
			}

			int dataLength = _rxBuffer[1] | (_rxBuffer[2] << 8);
			if (dataLength < 0 || dataLength > 4096)
			{
				_crcErrorCount += 1;
				_rxBuffer.RemoveAt(0);
				continue;
			}

			int frameLength = 5 + 2 + dataLength + 2;
			if (_rxBuffer.Count < frameLength)
			{
				return;
			}

			byte[] frame = _rxBuffer.GetRange(0, frameLength).ToArray();
			if (!VerifyCrc16(frame))
			{
				_crcErrorCount += 1;
				_rxBuffer.RemoveAt(0);
				continue;
			}

			ushort cmdId = (ushort)(frame[5] | (frame[6] << 8));
			byte[] payload = new byte[dataLength];
			Buffer.BlockCopy(frame, 7, payload, 0, dataLength);

			if (cmdId == CMD_ID_0302 && payload.Length == 30)
			{
				_frame0302Queue.Enqueue(payload);
			}
			else
			{
				_ignoredFrameCount += 1;
			}

			_rxBuffer.RemoveRange(0, frameLength);
		}
	}

	private static Parity ParseParity(string parity)
	{
		if (string.IsNullOrWhiteSpace(parity))
		{
			return Parity.None;
		}

		return parity.Trim().ToLowerInvariant() switch
		{
			"odd" => Parity.Odd,
			"even" => Parity.Even,
			"mark" => Parity.Mark,
			"space" => Parity.Space,
			_ => Parity.None
		};
	}

	private static StopBits ParseStopBits(int stopBits)
	{
		return stopBits switch
		{
			2 => StopBits.Two,
			_ => StopBits.One
		};
	}

	private static bool VerifyCrc8(byte[] header)
	{
		if (header == null || header.Length < 5)
		{
			return false;
		}
		byte expected = GetCrc8(header, 4, CRC8_INIT);
		return expected == header[4];
	}

	private static bool VerifyCrc16(byte[] frame)
	{
		if (frame == null || frame.Length < 9)
		{
			return false;
		}
		ushort expected = GetCrc16(frame, frame.Length - 2, CRC16_INIT);
		ushort actual = (ushort)(frame[frame.Length - 2] | (frame[frame.Length - 1] << 8));
		return expected == actual;
	}

	private static byte GetCrc8(byte[] data, int length, byte init)
	{
		byte crc = init;
		for (int i = 0; i < length; i++)
		{
			crc ^= data[i];
			for (int j = 0; j < 8; j++)
			{
				if ((crc & 0x01) != 0)
				{
					crc = (byte)((crc >> 1) ^ 0x8C);
				}
				else
				{
					crc >>= 1;
				}
			}
		}
		return crc;
	}

	private static ushort GetCrc16(byte[] data, int length, ushort init)
	{
		ushort crc = init;
		for (int i = 0; i < length; i++)
		{
			crc ^= data[i];
			for (int j = 0; j < 8; j++)
			{
				if ((crc & 0x0001) != 0)
				{
					crc = (ushort)((crc >> 1) ^ 0x8408);
				}
				else
				{
					crc >>= 1;
				}
			}
		}
		return crc;
	}
}
