class_name RMProto

#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		else:
			# Convert to big endian
			var slice: PackedByteArray = bytes.slice(index, index + count)
			slice.reverse()
			return slice

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10: # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break							
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class RemoteControl:
	func _init():
		var service
		
		__mouse_x = PBField.new("mouse_x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __mouse_x
		data[__mouse_x.tag] = service
		
		__mouse_y = PBField.new("mouse_y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __mouse_y
		data[__mouse_y.tag] = service
		
		__mouse_z = PBField.new("mouse_z", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __mouse_z
		data[__mouse_z.tag] = service
		
		__left_button_down = PBField.new("left_button_down", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __left_button_down
		data[__left_button_down.tag] = service
		
		__right_button_down = PBField.new("right_button_down", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __right_button_down
		data[__right_button_down.tag] = service
		
		__keyboard_value = PBField.new("keyboard_value", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __keyboard_value
		data[__keyboard_value.tag] = service
		
		__mid_button_down = PBField.new("mid_button_down", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __mid_button_down
		data[__mid_button_down.tag] = service
		
		__data = PBField.new("data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __data
		data[__data.tag] = service
		
	var data = {}
	
	var __mouse_x: PBField
	func has_mouse_x() -> bool:
		if __mouse_x.value != null:
			return true
		return false
	func get_mouse_x() -> int:
		return __mouse_x.value
	func clear_mouse_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__mouse_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_mouse_x(value : int) -> void:
		__mouse_x.value = value
	
	var __mouse_y: PBField
	func has_mouse_y() -> bool:
		if __mouse_y.value != null:
			return true
		return false
	func get_mouse_y() -> int:
		return __mouse_y.value
	func clear_mouse_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__mouse_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_mouse_y(value : int) -> void:
		__mouse_y.value = value
	
	var __mouse_z: PBField
	func has_mouse_z() -> bool:
		if __mouse_z.value != null:
			return true
		return false
	func get_mouse_z() -> int:
		return __mouse_z.value
	func clear_mouse_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__mouse_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_mouse_z(value : int) -> void:
		__mouse_z.value = value
	
	var __left_button_down: PBField
	func has_left_button_down() -> bool:
		if __left_button_down.value != null:
			return true
		return false
	func get_left_button_down() -> bool:
		return __left_button_down.value
	func clear_left_button_down() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__left_button_down.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_left_button_down(value : bool) -> void:
		__left_button_down.value = value
	
	var __right_button_down: PBField
	func has_right_button_down() -> bool:
		if __right_button_down.value != null:
			return true
		return false
	func get_right_button_down() -> bool:
		return __right_button_down.value
	func clear_right_button_down() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__right_button_down.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_right_button_down(value : bool) -> void:
		__right_button_down.value = value
	
	var __keyboard_value: PBField
	func has_keyboard_value() -> bool:
		if __keyboard_value.value != null:
			return true
		return false
	func get_keyboard_value() -> int:
		return __keyboard_value.value
	func clear_keyboard_value() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__keyboard_value.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_keyboard_value(value : int) -> void:
		__keyboard_value.value = value
	
	var __mid_button_down: PBField
	func has_mid_button_down() -> bool:
		if __mid_button_down.value != null:
			return true
		return false
	func get_mid_button_down() -> bool:
		return __mid_button_down.value
	func clear_mid_button_down() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__mid_button_down.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_mid_button_down(value : bool) -> void:
		__mid_button_down.value = value
	
	var __data: PBField
	func has_data() -> bool:
		if __data.value != null:
			return true
		return false
	func get_data() -> PackedByteArray:
		return __data.value
	func clear_data() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_data(value : PackedByteArray) -> void:
		__data.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameStatus:
	func _init():
		var service
		
		__current_round = PBField.new("current_round", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_round
		data[__current_round.tag] = service
		
		__total_rounds = PBField.new("total_rounds", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __total_rounds
		data[__total_rounds.tag] = service
		
		__red_score = PBField.new("red_score", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __red_score
		data[__red_score.tag] = service
		
		__blue_score = PBField.new("blue_score", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __blue_score
		data[__blue_score.tag] = service
		
		__current_stage = PBField.new("current_stage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_stage
		data[__current_stage.tag] = service
		
		__stage_countdown_sec = PBField.new("stage_countdown_sec", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __stage_countdown_sec
		data[__stage_countdown_sec.tag] = service
		
		__stage_elapsed_sec = PBField.new("stage_elapsed_sec", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __stage_elapsed_sec
		data[__stage_elapsed_sec.tag] = service
		
		__is_paused = PBField.new("is_paused", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_paused
		data[__is_paused.tag] = service
		
	var data = {}
	
	var __current_round: PBField
	func has_current_round() -> bool:
		if __current_round.value != null:
			return true
		return false
	func get_current_round() -> int:
		return __current_round.value
	func clear_current_round() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__current_round.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_round(value : int) -> void:
		__current_round.value = value
	
	var __total_rounds: PBField
	func has_total_rounds() -> bool:
		if __total_rounds.value != null:
			return true
		return false
	func get_total_rounds() -> int:
		return __total_rounds.value
	func clear_total_rounds() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__total_rounds.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_total_rounds(value : int) -> void:
		__total_rounds.value = value
	
	var __red_score: PBField
	func has_red_score() -> bool:
		if __red_score.value != null:
			return true
		return false
	func get_red_score() -> int:
		return __red_score.value
	func clear_red_score() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__red_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_red_score(value : int) -> void:
		__red_score.value = value
	
	var __blue_score: PBField
	func has_blue_score() -> bool:
		if __blue_score.value != null:
			return true
		return false
	func get_blue_score() -> int:
		return __blue_score.value
	func clear_blue_score() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__blue_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_blue_score(value : int) -> void:
		__blue_score.value = value
	
	var __current_stage: PBField
	func has_current_stage() -> bool:
		if __current_stage.value != null:
			return true
		return false
	func get_current_stage() -> int:
		return __current_stage.value
	func clear_current_stage() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__current_stage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_stage(value : int) -> void:
		__current_stage.value = value
	
	var __stage_countdown_sec: PBField
	func has_stage_countdown_sec() -> bool:
		if __stage_countdown_sec.value != null:
			return true
		return false
	func get_stage_countdown_sec() -> int:
		return __stage_countdown_sec.value
	func clear_stage_countdown_sec() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__stage_countdown_sec.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_stage_countdown_sec(value : int) -> void:
		__stage_countdown_sec.value = value
	
	var __stage_elapsed_sec: PBField
	func has_stage_elapsed_sec() -> bool:
		if __stage_elapsed_sec.value != null:
			return true
		return false
	func get_stage_elapsed_sec() -> int:
		return __stage_elapsed_sec.value
	func clear_stage_elapsed_sec() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__stage_elapsed_sec.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_stage_elapsed_sec(value : int) -> void:
		__stage_elapsed_sec.value = value
	
	var __is_paused: PBField
	func has_is_paused() -> bool:
		if __is_paused.value != null:
			return true
		return false
	func get_is_paused() -> bool:
		return __is_paused.value
	func clear_is_paused() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__is_paused.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_paused(value : bool) -> void:
		__is_paused.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GlobalUnitStatus:
	func _init():
		var service
		
		__base_health = PBField.new("base_health", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __base_health
		data[__base_health.tag] = service
		
		__base_status = PBField.new("base_status", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __base_status
		data[__base_status.tag] = service
		
		__base_shield = PBField.new("base_shield", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __base_shield
		data[__base_shield.tag] = service
		
		__outpost_health = PBField.new("outpost_health", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __outpost_health
		data[__outpost_health.tag] = service
		
		__outpost_status = PBField.new("outpost_status", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __outpost_status
		data[__outpost_status.tag] = service
		
		var __robot_health_default: Array[int] = []
		__robot_health = PBField.new("robot_health", PB_DATA_TYPE.UINT32, PB_RULE.REPEATED, 6, true, __robot_health_default)
		service = PBServiceField.new()
		service.field = __robot_health
		data[__robot_health.tag] = service
		
		var __robot_bullets_default: Array[int] = []
		__robot_bullets = PBField.new("robot_bullets", PB_DATA_TYPE.INT32, PB_RULE.REPEATED, 7, true, __robot_bullets_default)
		service = PBServiceField.new()
		service.field = __robot_bullets
		data[__robot_bullets.tag] = service
		
		__total_damage_red = PBField.new("total_damage_red", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __total_damage_red
		data[__total_damage_red.tag] = service
		
		__total_damage_blue = PBField.new("total_damage_blue", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __total_damage_blue
		data[__total_damage_blue.tag] = service
		
	var data = {}
	
	var __base_health: PBField
	func has_base_health() -> bool:
		if __base_health.value != null:
			return true
		return false
	func get_base_health() -> int:
		return __base_health.value
	func clear_base_health() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__base_health.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_base_health(value : int) -> void:
		__base_health.value = value
	
	var __base_status: PBField
	func has_base_status() -> bool:
		if __base_status.value != null:
			return true
		return false
	func get_base_status() -> int:
		return __base_status.value
	func clear_base_status() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__base_status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_base_status(value : int) -> void:
		__base_status.value = value
	
	var __base_shield: PBField
	func has_base_shield() -> bool:
		if __base_shield.value != null:
			return true
		return false
	func get_base_shield() -> int:
		return __base_shield.value
	func clear_base_shield() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__base_shield.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_base_shield(value : int) -> void:
		__base_shield.value = value
	
	var __outpost_health: PBField
	func has_outpost_health() -> bool:
		if __outpost_health.value != null:
			return true
		return false
	func get_outpost_health() -> int:
		return __outpost_health.value
	func clear_outpost_health() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__outpost_health.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_outpost_health(value : int) -> void:
		__outpost_health.value = value
	
	var __outpost_status: PBField
	func has_outpost_status() -> bool:
		if __outpost_status.value != null:
			return true
		return false
	func get_outpost_status() -> int:
		return __outpost_status.value
	func clear_outpost_status() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__outpost_status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_outpost_status(value : int) -> void:
		__outpost_status.value = value
	
	var __robot_health: PBField
	func get_robot_health() -> Array[int]:
		return __robot_health.value
	func clear_robot_health() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__robot_health.value.clear()
	func add_robot_health(value : int) -> void:
		__robot_health.value.append(value)
	
	var __robot_bullets: PBField
	func get_robot_bullets() -> Array[int]:
		return __robot_bullets.value
	func clear_robot_bullets() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__robot_bullets.value.clear()
	func add_robot_bullets(value : int) -> void:
		__robot_bullets.value.append(value)
	
	var __total_damage_red: PBField
	func has_total_damage_red() -> bool:
		if __total_damage_red.value != null:
			return true
		return false
	func get_total_damage_red() -> int:
		return __total_damage_red.value
	func clear_total_damage_red() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__total_damage_red.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_total_damage_red(value : int) -> void:
		__total_damage_red.value = value
	
	var __total_damage_blue: PBField
	func has_total_damage_blue() -> bool:
		if __total_damage_blue.value != null:
			return true
		return false
	func get_total_damage_blue() -> int:
		return __total_damage_blue.value
	func clear_total_damage_blue() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__total_damage_blue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_total_damage_blue(value : int) -> void:
		__total_damage_blue.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GlobalLogisticsStatus:
	func _init():
		var service
		
		__remaining_economy = PBField.new("remaining_economy", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __remaining_economy
		data[__remaining_economy.tag] = service
		
		__total_economy_obtained = PBField.new("total_economy_obtained", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __total_economy_obtained
		data[__total_economy_obtained.tag] = service
		
		__tech_level = PBField.new("tech_level", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __tech_level
		data[__tech_level.tag] = service
		
		__encryption_level = PBField.new("encryption_level", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __encryption_level
		data[__encryption_level.tag] = service
		
	var data = {}
	
	var __remaining_economy: PBField
	func has_remaining_economy() -> bool:
		if __remaining_economy.value != null:
			return true
		return false
	func get_remaining_economy() -> int:
		return __remaining_economy.value
	func clear_remaining_economy() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__remaining_economy.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_remaining_economy(value : int) -> void:
		__remaining_economy.value = value
	
	var __total_economy_obtained: PBField
	func has_total_economy_obtained() -> bool:
		if __total_economy_obtained.value != null:
			return true
		return false
	func get_total_economy_obtained() -> int:
		return __total_economy_obtained.value
	func clear_total_economy_obtained() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__total_economy_obtained.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_total_economy_obtained(value : int) -> void:
		__total_economy_obtained.value = value
	
	var __tech_level: PBField
	func has_tech_level() -> bool:
		if __tech_level.value != null:
			return true
		return false
	func get_tech_level() -> int:
		return __tech_level.value
	func clear_tech_level() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__tech_level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_tech_level(value : int) -> void:
		__tech_level.value = value
	
	var __encryption_level: PBField
	func has_encryption_level() -> bool:
		if __encryption_level.value != null:
			return true
		return false
	func get_encryption_level() -> int:
		return __encryption_level.value
	func clear_encryption_level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__encryption_level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_encryption_level(value : int) -> void:
		__encryption_level.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GlobalSpecialMechanism:
	func _init():
		var service
		
		var __mechanism_id_default: Array[int] = []
		__mechanism_id = PBField.new("mechanism_id", PB_DATA_TYPE.UINT32, PB_RULE.REPEATED, 1, true, __mechanism_id_default)
		service = PBServiceField.new()
		service.field = __mechanism_id
		data[__mechanism_id.tag] = service
		
		var __mechanism_time_sec_default: Array[int] = []
		__mechanism_time_sec = PBField.new("mechanism_time_sec", PB_DATA_TYPE.INT32, PB_RULE.REPEATED, 2, true, __mechanism_time_sec_default)
		service = PBServiceField.new()
		service.field = __mechanism_time_sec
		data[__mechanism_time_sec.tag] = service
		
	var data = {}
	
	var __mechanism_id: PBField
	func get_mechanism_id() -> Array[int]:
		return __mechanism_id.value
	func clear_mechanism_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__mechanism_id.value.clear()
	func add_mechanism_id(value : int) -> void:
		__mechanism_id.value.append(value)
	
	var __mechanism_time_sec: PBField
	func get_mechanism_time_sec() -> Array[int]:
		return __mechanism_time_sec.value
	func clear_mechanism_time_sec() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__mechanism_time_sec.value.clear()
	func add_mechanism_time_sec(value : int) -> void:
		__mechanism_time_sec.value.append(value)
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Event:
	func _init():
		var service
		
		__event_id = PBField.new("event_id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __event_id
		data[__event_id.tag] = service
		
		__param = PBField.new("param", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __param
		data[__param.tag] = service
		
	var data = {}
	
	var __event_id: PBField
	func has_event_id() -> bool:
		if __event_id.value != null:
			return true
		return false
	func get_event_id() -> int:
		return __event_id.value
	func clear_event_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__event_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_event_id(value : int) -> void:
		__event_id.value = value
	
	var __param: PBField
	func has_param() -> bool:
		if __param.value != null:
			return true
		return false
	func get_param() -> String:
		return __param.value
	func clear_param() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__param.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_param(value : String) -> void:
		__param.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotInjuryStat:
	func _init():
		var service
		
		__total_damage = PBField.new("total_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __total_damage
		data[__total_damage.tag] = service
		
		__collision_damage = PBField.new("collision_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __collision_damage
		data[__collision_damage.tag] = service
		
		__small_projectile_damage = PBField.new("small_projectile_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __small_projectile_damage
		data[__small_projectile_damage.tag] = service
		
		__large_projectile_damage = PBField.new("large_projectile_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __large_projectile_damage
		data[__large_projectile_damage.tag] = service
		
		__dart_splash_damage = PBField.new("dart_splash_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __dart_splash_damage
		data[__dart_splash_damage.tag] = service
		
		__module_offline_damage = PBField.new("module_offline_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __module_offline_damage
		data[__module_offline_damage.tag] = service
		
		__wifi_offline_damage = PBField.new("wifi_offline_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __wifi_offline_damage
		data[__wifi_offline_damage.tag] = service
		
		__penalty_damage = PBField.new("penalty_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __penalty_damage
		data[__penalty_damage.tag] = service
		
		__server_kill_damage = PBField.new("server_kill_damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __server_kill_damage
		data[__server_kill_damage.tag] = service
		
		__killer_id = PBField.new("killer_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __killer_id
		data[__killer_id.tag] = service
		
	var data = {}
	
	var __total_damage: PBField
	func has_total_damage() -> bool:
		if __total_damage.value != null:
			return true
		return false
	func get_total_damage() -> int:
		return __total_damage.value
	func clear_total_damage() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__total_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_total_damage(value : int) -> void:
		__total_damage.value = value
	
	var __collision_damage: PBField
	func has_collision_damage() -> bool:
		if __collision_damage.value != null:
			return true
		return false
	func get_collision_damage() -> int:
		return __collision_damage.value
	func clear_collision_damage() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__collision_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_collision_damage(value : int) -> void:
		__collision_damage.value = value
	
	var __small_projectile_damage: PBField
	func has_small_projectile_damage() -> bool:
		if __small_projectile_damage.value != null:
			return true
		return false
	func get_small_projectile_damage() -> int:
		return __small_projectile_damage.value
	func clear_small_projectile_damage() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__small_projectile_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_small_projectile_damage(value : int) -> void:
		__small_projectile_damage.value = value
	
	var __large_projectile_damage: PBField
	func has_large_projectile_damage() -> bool:
		if __large_projectile_damage.value != null:
			return true
		return false
	func get_large_projectile_damage() -> int:
		return __large_projectile_damage.value
	func clear_large_projectile_damage() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__large_projectile_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_large_projectile_damage(value : int) -> void:
		__large_projectile_damage.value = value
	
	var __dart_splash_damage: PBField
	func has_dart_splash_damage() -> bool:
		if __dart_splash_damage.value != null:
			return true
		return false
	func get_dart_splash_damage() -> int:
		return __dart_splash_damage.value
	func clear_dart_splash_damage() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__dart_splash_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_dart_splash_damage(value : int) -> void:
		__dart_splash_damage.value = value
	
	var __module_offline_damage: PBField
	func has_module_offline_damage() -> bool:
		if __module_offline_damage.value != null:
			return true
		return false
	func get_module_offline_damage() -> int:
		return __module_offline_damage.value
	func clear_module_offline_damage() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__module_offline_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_module_offline_damage(value : int) -> void:
		__module_offline_damage.value = value
	
	var __wifi_offline_damage: PBField
	func has_wifi_offline_damage() -> bool:
		if __wifi_offline_damage.value != null:
			return true
		return false
	func get_wifi_offline_damage() -> int:
		return __wifi_offline_damage.value
	func clear_wifi_offline_damage() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__wifi_offline_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_wifi_offline_damage(value : int) -> void:
		__wifi_offline_damage.value = value
	
	var __penalty_damage: PBField
	func has_penalty_damage() -> bool:
		if __penalty_damage.value != null:
			return true
		return false
	func get_penalty_damage() -> int:
		return __penalty_damage.value
	func clear_penalty_damage() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__penalty_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_penalty_damage(value : int) -> void:
		__penalty_damage.value = value
	
	var __server_kill_damage: PBField
	func has_server_kill_damage() -> bool:
		if __server_kill_damage.value != null:
			return true
		return false
	func get_server_kill_damage() -> int:
		return __server_kill_damage.value
	func clear_server_kill_damage() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__server_kill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_server_kill_damage(value : int) -> void:
		__server_kill_damage.value = value
	
	var __killer_id: PBField
	func has_killer_id() -> bool:
		if __killer_id.value != null:
			return true
		return false
	func get_killer_id() -> int:
		return __killer_id.value
	func clear_killer_id() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__killer_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_killer_id(value : int) -> void:
		__killer_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotRespawnStatus:
	func _init():
		var service
		
		__is_pending_respawn = PBField.new("is_pending_respawn", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_pending_respawn
		data[__is_pending_respawn.tag] = service
		
		__total_respawn_progress = PBField.new("total_respawn_progress", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __total_respawn_progress
		data[__total_respawn_progress.tag] = service
		
		__current_respawn_progress = PBField.new("current_respawn_progress", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_respawn_progress
		data[__current_respawn_progress.tag] = service
		
		__can_free_respawn = PBField.new("can_free_respawn", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __can_free_respawn
		data[__can_free_respawn.tag] = service
		
		__gold_cost_for_respawn = PBField.new("gold_cost_for_respawn", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __gold_cost_for_respawn
		data[__gold_cost_for_respawn.tag] = service
		
		__can_pay_for_respawn = PBField.new("can_pay_for_respawn", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __can_pay_for_respawn
		data[__can_pay_for_respawn.tag] = service
		
	var data = {}
	
	var __is_pending_respawn: PBField
	func has_is_pending_respawn() -> bool:
		if __is_pending_respawn.value != null:
			return true
		return false
	func get_is_pending_respawn() -> bool:
		return __is_pending_respawn.value
	func clear_is_pending_respawn() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__is_pending_respawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_pending_respawn(value : bool) -> void:
		__is_pending_respawn.value = value
	
	var __total_respawn_progress: PBField
	func has_total_respawn_progress() -> bool:
		if __total_respawn_progress.value != null:
			return true
		return false
	func get_total_respawn_progress() -> int:
		return __total_respawn_progress.value
	func clear_total_respawn_progress() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__total_respawn_progress.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_total_respawn_progress(value : int) -> void:
		__total_respawn_progress.value = value
	
	var __current_respawn_progress: PBField
	func has_current_respawn_progress() -> bool:
		if __current_respawn_progress.value != null:
			return true
		return false
	func get_current_respawn_progress() -> int:
		return __current_respawn_progress.value
	func clear_current_respawn_progress() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__current_respawn_progress.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_respawn_progress(value : int) -> void:
		__current_respawn_progress.value = value
	
	var __can_free_respawn: PBField
	func has_can_free_respawn() -> bool:
		if __can_free_respawn.value != null:
			return true
		return false
	func get_can_free_respawn() -> bool:
		return __can_free_respawn.value
	func clear_can_free_respawn() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__can_free_respawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_can_free_respawn(value : bool) -> void:
		__can_free_respawn.value = value
	
	var __gold_cost_for_respawn: PBField
	func has_gold_cost_for_respawn() -> bool:
		if __gold_cost_for_respawn.value != null:
			return true
		return false
	func get_gold_cost_for_respawn() -> int:
		return __gold_cost_for_respawn.value
	func clear_gold_cost_for_respawn() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__gold_cost_for_respawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_gold_cost_for_respawn(value : int) -> void:
		__gold_cost_for_respawn.value = value
	
	var __can_pay_for_respawn: PBField
	func has_can_pay_for_respawn() -> bool:
		if __can_pay_for_respawn.value != null:
			return true
		return false
	func get_can_pay_for_respawn() -> bool:
		return __can_pay_for_respawn.value
	func clear_can_pay_for_respawn() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__can_pay_for_respawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_can_pay_for_respawn(value : bool) -> void:
		__can_pay_for_respawn.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotStaticStatus:
	func _init():
		var service
		
		__connection_state = PBField.new("connection_state", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __connection_state
		data[__connection_state.tag] = service
		
		__field_state = PBField.new("field_state", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __field_state
		data[__field_state.tag] = service
		
		__alive_state = PBField.new("alive_state", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __alive_state
		data[__alive_state.tag] = service
		
		__robot_id = PBField.new("robot_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __robot_id
		data[__robot_id.tag] = service
		
		__robot_type = PBField.new("robot_type", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __robot_type
		data[__robot_type.tag] = service
		
		__performance_system_shooter = PBField.new("performance_system_shooter", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __performance_system_shooter
		data[__performance_system_shooter.tag] = service
		
		__performance_system_chassis = PBField.new("performance_system_chassis", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __performance_system_chassis
		data[__performance_system_chassis.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__max_health = PBField.new("max_health", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_health
		data[__max_health.tag] = service
		
		__max_heat = PBField.new("max_heat", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_heat
		data[__max_heat.tag] = service
		
		__heat_cooldown_rate = PBField.new("heat_cooldown_rate", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __heat_cooldown_rate
		data[__heat_cooldown_rate.tag] = service
		
		__max_power = PBField.new("max_power", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_power
		data[__max_power.tag] = service
		
		__max_buffer_energy = PBField.new("max_buffer_energy", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_buffer_energy
		data[__max_buffer_energy.tag] = service
		
		__max_chassis_energy = PBField.new("max_chassis_energy", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_chassis_energy
		data[__max_chassis_energy.tag] = service
		
	var data = {}
	
	var __connection_state: PBField
	func has_connection_state() -> bool:
		if __connection_state.value != null:
			return true
		return false
	func get_connection_state() -> int:
		return __connection_state.value
	func clear_connection_state() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__connection_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_connection_state(value : int) -> void:
		__connection_state.value = value
	
	var __field_state: PBField
	func has_field_state() -> bool:
		if __field_state.value != null:
			return true
		return false
	func get_field_state() -> int:
		return __field_state.value
	func clear_field_state() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__field_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_field_state(value : int) -> void:
		__field_state.value = value
	
	var __alive_state: PBField
	func has_alive_state() -> bool:
		if __alive_state.value != null:
			return true
		return false
	func get_alive_state() -> int:
		return __alive_state.value
	func clear_alive_state() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__alive_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_alive_state(value : int) -> void:
		__alive_state.value = value
	
	var __robot_id: PBField
	func has_robot_id() -> bool:
		if __robot_id.value != null:
			return true
		return false
	func get_robot_id() -> int:
		return __robot_id.value
	func clear_robot_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__robot_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_robot_id(value : int) -> void:
		__robot_id.value = value
	
	var __robot_type: PBField
	func has_robot_type() -> bool:
		if __robot_type.value != null:
			return true
		return false
	func get_robot_type() -> int:
		return __robot_type.value
	func clear_robot_type() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__robot_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_robot_type(value : int) -> void:
		__robot_type.value = value
	
	var __performance_system_shooter: PBField
	func has_performance_system_shooter() -> bool:
		if __performance_system_shooter.value != null:
			return true
		return false
	func get_performance_system_shooter() -> int:
		return __performance_system_shooter.value
	func clear_performance_system_shooter() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__performance_system_shooter.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_performance_system_shooter(value : int) -> void:
		__performance_system_shooter.value = value
	
	var __performance_system_chassis: PBField
	func has_performance_system_chassis() -> bool:
		if __performance_system_chassis.value != null:
			return true
		return false
	func get_performance_system_chassis() -> int:
		return __performance_system_chassis.value
	func clear_performance_system_chassis() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__performance_system_chassis.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_performance_system_chassis(value : int) -> void:
		__performance_system_chassis.value = value
	
	var __level: PBField
	func has_level() -> bool:
		if __level.value != null:
			return true
		return false
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __max_health: PBField
	func has_max_health() -> bool:
		if __max_health.value != null:
			return true
		return false
	func get_max_health() -> int:
		return __max_health.value
	func clear_max_health() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__max_health.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_health(value : int) -> void:
		__max_health.value = value
	
	var __max_heat: PBField
	func has_max_heat() -> bool:
		if __max_heat.value != null:
			return true
		return false
	func get_max_heat() -> int:
		return __max_heat.value
	func clear_max_heat() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__max_heat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_heat(value : int) -> void:
		__max_heat.value = value
	
	var __heat_cooldown_rate: PBField
	func has_heat_cooldown_rate() -> bool:
		if __heat_cooldown_rate.value != null:
			return true
		return false
	func get_heat_cooldown_rate() -> float:
		return __heat_cooldown_rate.value
	func clear_heat_cooldown_rate() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__heat_cooldown_rate.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_heat_cooldown_rate(value : float) -> void:
		__heat_cooldown_rate.value = value
	
	var __max_power: PBField
	func has_max_power() -> bool:
		if __max_power.value != null:
			return true
		return false
	func get_max_power() -> int:
		return __max_power.value
	func clear_max_power() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__max_power.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_power(value : int) -> void:
		__max_power.value = value
	
	var __max_buffer_energy: PBField
	func has_max_buffer_energy() -> bool:
		if __max_buffer_energy.value != null:
			return true
		return false
	func get_max_buffer_energy() -> int:
		return __max_buffer_energy.value
	func clear_max_buffer_energy() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__max_buffer_energy.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_buffer_energy(value : int) -> void:
		__max_buffer_energy.value = value
	
	var __max_chassis_energy: PBField
	func has_max_chassis_energy() -> bool:
		if __max_chassis_energy.value != null:
			return true
		return false
	func get_max_chassis_energy() -> int:
		return __max_chassis_energy.value
	func clear_max_chassis_energy() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__max_chassis_energy.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_chassis_energy(value : int) -> void:
		__max_chassis_energy.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotDynamicStatus:
	func _init():
		var service
		
		__current_health = PBField.new("current_health", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_health
		data[__current_health.tag] = service
		
		__current_heat = PBField.new("current_heat", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __current_heat
		data[__current_heat.tag] = service
		
		__last_projectile_fire_rate = PBField.new("last_projectile_fire_rate", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __last_projectile_fire_rate
		data[__last_projectile_fire_rate.tag] = service
		
		__current_chassis_energy = PBField.new("current_chassis_energy", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_chassis_energy
		data[__current_chassis_energy.tag] = service
		
		__current_buffer_energy = PBField.new("current_buffer_energy", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_buffer_energy
		data[__current_buffer_energy.tag] = service
		
		__current_experience = PBField.new("current_experience", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_experience
		data[__current_experience.tag] = service
		
		__experience_for_upgrade = PBField.new("experience_for_upgrade", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __experience_for_upgrade
		data[__experience_for_upgrade.tag] = service
		
		__total_projectiles_fired = PBField.new("total_projectiles_fired", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __total_projectiles_fired
		data[__total_projectiles_fired.tag] = service
		
		__remaining_ammo = PBField.new("remaining_ammo", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __remaining_ammo
		data[__remaining_ammo.tag] = service
		
		__is_out_of_combat = PBField.new("is_out_of_combat", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_out_of_combat
		data[__is_out_of_combat.tag] = service
		
		__out_of_combat_countdown = PBField.new("out_of_combat_countdown", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __out_of_combat_countdown
		data[__out_of_combat_countdown.tag] = service
		
		__can_remote_heal = PBField.new("can_remote_heal", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __can_remote_heal
		data[__can_remote_heal.tag] = service
		
		__can_remote_ammo = PBField.new("can_remote_ammo", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __can_remote_ammo
		data[__can_remote_ammo.tag] = service
		
	var data = {}
	
	var __current_health: PBField
	func has_current_health() -> bool:
		if __current_health.value != null:
			return true
		return false
	func get_current_health() -> int:
		return __current_health.value
	func clear_current_health() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__current_health.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_health(value : int) -> void:
		__current_health.value = value
	
	var __current_heat: PBField
	func has_current_heat() -> bool:
		if __current_heat.value != null:
			return true
		return false
	func get_current_heat() -> float:
		return __current_heat.value
	func clear_current_heat() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__current_heat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_current_heat(value : float) -> void:
		__current_heat.value = value
	
	var __last_projectile_fire_rate: PBField
	func has_last_projectile_fire_rate() -> bool:
		if __last_projectile_fire_rate.value != null:
			return true
		return false
	func get_last_projectile_fire_rate() -> float:
		return __last_projectile_fire_rate.value
	func clear_last_projectile_fire_rate() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__last_projectile_fire_rate.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_last_projectile_fire_rate(value : float) -> void:
		__last_projectile_fire_rate.value = value
	
	var __current_chassis_energy: PBField
	func has_current_chassis_energy() -> bool:
		if __current_chassis_energy.value != null:
			return true
		return false
	func get_current_chassis_energy() -> int:
		return __current_chassis_energy.value
	func clear_current_chassis_energy() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__current_chassis_energy.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_chassis_energy(value : int) -> void:
		__current_chassis_energy.value = value
	
	var __current_buffer_energy: PBField
	func has_current_buffer_energy() -> bool:
		if __current_buffer_energy.value != null:
			return true
		return false
	func get_current_buffer_energy() -> int:
		return __current_buffer_energy.value
	func clear_current_buffer_energy() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__current_buffer_energy.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_buffer_energy(value : int) -> void:
		__current_buffer_energy.value = value
	
	var __current_experience: PBField
	func has_current_experience() -> bool:
		if __current_experience.value != null:
			return true
		return false
	func get_current_experience() -> int:
		return __current_experience.value
	func clear_current_experience() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__current_experience.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_experience(value : int) -> void:
		__current_experience.value = value
	
	var __experience_for_upgrade: PBField
	func has_experience_for_upgrade() -> bool:
		if __experience_for_upgrade.value != null:
			return true
		return false
	func get_experience_for_upgrade() -> int:
		return __experience_for_upgrade.value
	func clear_experience_for_upgrade() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__experience_for_upgrade.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_experience_for_upgrade(value : int) -> void:
		__experience_for_upgrade.value = value
	
	var __total_projectiles_fired: PBField
	func has_total_projectiles_fired() -> bool:
		if __total_projectiles_fired.value != null:
			return true
		return false
	func get_total_projectiles_fired() -> int:
		return __total_projectiles_fired.value
	func clear_total_projectiles_fired() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__total_projectiles_fired.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_total_projectiles_fired(value : int) -> void:
		__total_projectiles_fired.value = value
	
	var __remaining_ammo: PBField
	func has_remaining_ammo() -> bool:
		if __remaining_ammo.value != null:
			return true
		return false
	func get_remaining_ammo() -> int:
		return __remaining_ammo.value
	func clear_remaining_ammo() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__remaining_ammo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_remaining_ammo(value : int) -> void:
		__remaining_ammo.value = value
	
	var __is_out_of_combat: PBField
	func has_is_out_of_combat() -> bool:
		if __is_out_of_combat.value != null:
			return true
		return false
	func get_is_out_of_combat() -> bool:
		return __is_out_of_combat.value
	func clear_is_out_of_combat() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__is_out_of_combat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_out_of_combat(value : bool) -> void:
		__is_out_of_combat.value = value
	
	var __out_of_combat_countdown: PBField
	func has_out_of_combat_countdown() -> bool:
		if __out_of_combat_countdown.value != null:
			return true
		return false
	func get_out_of_combat_countdown() -> int:
		return __out_of_combat_countdown.value
	func clear_out_of_combat_countdown() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__out_of_combat_countdown.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_out_of_combat_countdown(value : int) -> void:
		__out_of_combat_countdown.value = value
	
	var __can_remote_heal: PBField
	func has_can_remote_heal() -> bool:
		if __can_remote_heal.value != null:
			return true
		return false
	func get_can_remote_heal() -> bool:
		return __can_remote_heal.value
	func clear_can_remote_heal() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__can_remote_heal.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_can_remote_heal(value : bool) -> void:
		__can_remote_heal.value = value
	
	var __can_remote_ammo: PBField
	func has_can_remote_ammo() -> bool:
		if __can_remote_ammo.value != null:
			return true
		return false
	func get_can_remote_ammo() -> bool:
		return __can_remote_ammo.value
	func clear_can_remote_ammo() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__can_remote_ammo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_can_remote_ammo(value : bool) -> void:
		__can_remote_ammo.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotModuleStatus:
	func _init():
		var service
		
		__power_manager = PBField.new("power_manager", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __power_manager
		data[__power_manager.tag] = service
		
		__rfid = PBField.new("rfid", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __rfid
		data[__rfid.tag] = service
		
		__light_strip = PBField.new("light_strip", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __light_strip
		data[__light_strip.tag] = service
		
		__small_shooter = PBField.new("small_shooter", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __small_shooter
		data[__small_shooter.tag] = service
		
		__big_shooter = PBField.new("big_shooter", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __big_shooter
		data[__big_shooter.tag] = service
		
		__uwb = PBField.new("uwb", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __uwb
		data[__uwb.tag] = service
		
		__armor = PBField.new("armor", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __armor
		data[__armor.tag] = service
		
		__video_transmission = PBField.new("video_transmission", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __video_transmission
		data[__video_transmission.tag] = service
		
		__capacitor = PBField.new("capacitor", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __capacitor
		data[__capacitor.tag] = service
		
		__main_controller = PBField.new("main_controller", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __main_controller
		data[__main_controller.tag] = service
		
	var data = {}
	
	var __power_manager: PBField
	func has_power_manager() -> bool:
		if __power_manager.value != null:
			return true
		return false
	func get_power_manager() -> int:
		return __power_manager.value
	func clear_power_manager() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__power_manager.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_power_manager(value : int) -> void:
		__power_manager.value = value
	
	var __rfid: PBField
	func has_rfid() -> bool:
		if __rfid.value != null:
			return true
		return false
	func get_rfid() -> int:
		return __rfid.value
	func clear_rfid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__rfid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_rfid(value : int) -> void:
		__rfid.value = value
	
	var __light_strip: PBField
	func has_light_strip() -> bool:
		if __light_strip.value != null:
			return true
		return false
	func get_light_strip() -> int:
		return __light_strip.value
	func clear_light_strip() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__light_strip.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_light_strip(value : int) -> void:
		__light_strip.value = value
	
	var __small_shooter: PBField
	func has_small_shooter() -> bool:
		if __small_shooter.value != null:
			return true
		return false
	func get_small_shooter() -> int:
		return __small_shooter.value
	func clear_small_shooter() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__small_shooter.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_small_shooter(value : int) -> void:
		__small_shooter.value = value
	
	var __big_shooter: PBField
	func has_big_shooter() -> bool:
		if __big_shooter.value != null:
			return true
		return false
	func get_big_shooter() -> int:
		return __big_shooter.value
	func clear_big_shooter() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__big_shooter.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_big_shooter(value : int) -> void:
		__big_shooter.value = value
	
	var __uwb: PBField
	func has_uwb() -> bool:
		if __uwb.value != null:
			return true
		return false
	func get_uwb() -> int:
		return __uwb.value
	func clear_uwb() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__uwb.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_uwb(value : int) -> void:
		__uwb.value = value
	
	var __armor: PBField
	func has_armor() -> bool:
		if __armor.value != null:
			return true
		return false
	func get_armor() -> int:
		return __armor.value
	func clear_armor() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__armor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_armor(value : int) -> void:
		__armor.value = value
	
	var __video_transmission: PBField
	func has_video_transmission() -> bool:
		if __video_transmission.value != null:
			return true
		return false
	func get_video_transmission() -> int:
		return __video_transmission.value
	func clear_video_transmission() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__video_transmission.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_video_transmission(value : int) -> void:
		__video_transmission.value = value
	
	var __capacitor: PBField
	func has_capacitor() -> bool:
		if __capacitor.value != null:
			return true
		return false
	func get_capacitor() -> int:
		return __capacitor.value
	func clear_capacitor() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__capacitor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_capacitor(value : int) -> void:
		__capacitor.value = value
	
	var __main_controller: PBField
	func has_main_controller() -> bool:
		if __main_controller.value != null:
			return true
		return false
	func get_main_controller() -> int:
		return __main_controller.value
	func clear_main_controller() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__main_controller.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_main_controller(value : int) -> void:
		__main_controller.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotPosition:
	func _init():
		var service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__z = PBField.new("z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __z
		data[__z.tag] = service
		
		__yaw = PBField.new("yaw", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __yaw
		data[__yaw.tag] = service
		
	var data = {}
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __z: PBField
	func has_z() -> bool:
		if __z.value != null:
			return true
		return false
	func get_z() -> float:
		return __z.value
	func clear_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_z(value : float) -> void:
		__z.value = value
	
	var __yaw: PBField
	func has_yaw() -> bool:
		if __yaw.value != null:
			return true
		return false
	func get_yaw() -> float:
		return __yaw.value
	func clear_yaw() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__yaw.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_yaw(value : float) -> void:
		__yaw.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Buff:
	func _init():
		var service
		
		__robot_id = PBField.new("robot_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __robot_id
		data[__robot_id.tag] = service
		
		__buff_type = PBField.new("buff_type", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __buff_type
		data[__buff_type.tag] = service
		
		__buff_level = PBField.new("buff_level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __buff_level
		data[__buff_level.tag] = service
		
		__buff_max_time = PBField.new("buff_max_time", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __buff_max_time
		data[__buff_max_time.tag] = service
		
		__buff_left_time = PBField.new("buff_left_time", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __buff_left_time
		data[__buff_left_time.tag] = service
		
		__msg_params = PBField.new("msg_params", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __msg_params
		data[__msg_params.tag] = service
		
	var data = {}
	
	var __robot_id: PBField
	func has_robot_id() -> bool:
		if __robot_id.value != null:
			return true
		return false
	func get_robot_id() -> int:
		return __robot_id.value
	func clear_robot_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__robot_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_robot_id(value : int) -> void:
		__robot_id.value = value
	
	var __buff_type: PBField
	func has_buff_type() -> bool:
		if __buff_type.value != null:
			return true
		return false
	func get_buff_type() -> int:
		return __buff_type.value
	func clear_buff_type() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__buff_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_buff_type(value : int) -> void:
		__buff_type.value = value
	
	var __buff_level: PBField
	func has_buff_level() -> bool:
		if __buff_level.value != null:
			return true
		return false
	func get_buff_level() -> int:
		return __buff_level.value
	func clear_buff_level() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__buff_level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_buff_level(value : int) -> void:
		__buff_level.value = value
	
	var __buff_max_time: PBField
	func has_buff_max_time() -> bool:
		if __buff_max_time.value != null:
			return true
		return false
	func get_buff_max_time() -> int:
		return __buff_max_time.value
	func clear_buff_max_time() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__buff_max_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_buff_max_time(value : int) -> void:
		__buff_max_time.value = value
	
	var __buff_left_time: PBField
	func has_buff_left_time() -> bool:
		if __buff_left_time.value != null:
			return true
		return false
	func get_buff_left_time() -> int:
		return __buff_left_time.value
	func clear_buff_left_time() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__buff_left_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_buff_left_time(value : int) -> void:
		__buff_left_time.value = value
	
	var __msg_params: PBField
	func has_msg_params() -> bool:
		if __msg_params.value != null:
			return true
		return false
	func get_msg_params() -> String:
		return __msg_params.value
	func clear_msg_params() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__msg_params.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_msg_params(value : String) -> void:
		__msg_params.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PenaltyInfo:
	func _init():
		var service
		
		__penalty_type = PBField.new("penalty_type", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __penalty_type
		data[__penalty_type.tag] = service
		
		__penalty_effect_sec = PBField.new("penalty_effect_sec", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __penalty_effect_sec
		data[__penalty_effect_sec.tag] = service
		
		__total_penalty_num = PBField.new("total_penalty_num", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __total_penalty_num
		data[__total_penalty_num.tag] = service
		
	var data = {}
	
	var __penalty_type: PBField
	func has_penalty_type() -> bool:
		if __penalty_type.value != null:
			return true
		return false
	func get_penalty_type() -> int:
		return __penalty_type.value
	func clear_penalty_type() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__penalty_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_penalty_type(value : int) -> void:
		__penalty_type.value = value
	
	var __penalty_effect_sec: PBField
	func has_penalty_effect_sec() -> bool:
		if __penalty_effect_sec.value != null:
			return true
		return false
	func get_penalty_effect_sec() -> int:
		return __penalty_effect_sec.value
	func clear_penalty_effect_sec() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__penalty_effect_sec.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_penalty_effect_sec(value : int) -> void:
		__penalty_effect_sec.value = value
	
	var __total_penalty_num: PBField
	func has_total_penalty_num() -> bool:
		if __total_penalty_num.value != null:
			return true
		return false
	func get_total_penalty_num() -> int:
		return __total_penalty_num.value
	func clear_total_penalty_num() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__total_penalty_num.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_total_penalty_num(value : int) -> void:
		__total_penalty_num.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotPathPlanInfo:
	func _init():
		var service
		
		__intention = PBField.new("intention", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __intention
		data[__intention.tag] = service
		
		__start_pos_x = PBField.new("start_pos_x", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __start_pos_x
		data[__start_pos_x.tag] = service
		
		__start_pos_y = PBField.new("start_pos_y", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __start_pos_y
		data[__start_pos_y.tag] = service
		
		var __offset_x_default: Array[int] = []
		__offset_x = PBField.new("offset_x", PB_DATA_TYPE.INT32, PB_RULE.REPEATED, 4, true, __offset_x_default)
		service = PBServiceField.new()
		service.field = __offset_x
		data[__offset_x.tag] = service
		
		var __offset_y_default: Array[int] = []
		__offset_y = PBField.new("offset_y", PB_DATA_TYPE.INT32, PB_RULE.REPEATED, 5, true, __offset_y_default)
		service = PBServiceField.new()
		service.field = __offset_y
		data[__offset_y.tag] = service
		
		__sender_id = PBField.new("sender_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __sender_id
		data[__sender_id.tag] = service
		
	var data = {}
	
	var __intention: PBField
	func has_intention() -> bool:
		if __intention.value != null:
			return true
		return false
	func get_intention() -> int:
		return __intention.value
	func clear_intention() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__intention.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_intention(value : int) -> void:
		__intention.value = value
	
	var __start_pos_x: PBField
	func has_start_pos_x() -> bool:
		if __start_pos_x.value != null:
			return true
		return false
	func get_start_pos_x() -> int:
		return __start_pos_x.value
	func clear_start_pos_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__start_pos_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_start_pos_x(value : int) -> void:
		__start_pos_x.value = value
	
	var __start_pos_y: PBField
	func has_start_pos_y() -> bool:
		if __start_pos_y.value != null:
			return true
		return false
	func get_start_pos_y() -> int:
		return __start_pos_y.value
	func clear_start_pos_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__start_pos_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_start_pos_y(value : int) -> void:
		__start_pos_y.value = value
	
	var __offset_x: PBField
	func get_offset_x() -> Array[int]:
		return __offset_x.value
	func clear_offset_x() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__offset_x.value.clear()
	func add_offset_x(value : int) -> void:
		__offset_x.value.append(value)
	
	var __offset_y: PBField
	func get_offset_y() -> Array[int]:
		return __offset_y.value
	func clear_offset_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__offset_y.value.clear()
	func add_offset_y(value : int) -> void:
		__offset_y.value.append(value)
	
	var __sender_id: PBField
	func has_sender_id() -> bool:
		if __sender_id.value != null:
			return true
		return false
	func get_sender_id() -> int:
		return __sender_id.value
	func clear_sender_id() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__sender_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_sender_id(value : int) -> void:
		__sender_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MapClickInfoNotify:
	func _init():
		var service
		
		__is_send_all = PBField.new("is_send_all", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __is_send_all
		data[__is_send_all.tag] = service
		
		__robot_id = PBField.new("robot_id", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __robot_id
		data[__robot_id.tag] = service
		
		__mode = PBField.new("mode", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __mode
		data[__mode.tag] = service
		
		__enemy_id = PBField.new("enemy_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __enemy_id
		data[__enemy_id.tag] = service
		
		__ascii = PBField.new("ascii", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ascii
		data[__ascii.tag] = service
		
		__type = PBField.new("type", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __type
		data[__type.tag] = service
		
		__screen_x = PBField.new("screen_x", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __screen_x
		data[__screen_x.tag] = service
		
		__screen_y = PBField.new("screen_y", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __screen_y
		data[__screen_y.tag] = service
		
		__map_x = PBField.new("map_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __map_x
		data[__map_x.tag] = service
		
		__map_y = PBField.new("map_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __map_y
		data[__map_y.tag] = service
		
	var data = {}
	
	var __is_send_all: PBField
	func has_is_send_all() -> bool:
		if __is_send_all.value != null:
			return true
		return false
	func get_is_send_all() -> int:
		return __is_send_all.value
	func clear_is_send_all() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__is_send_all.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_is_send_all(value : int) -> void:
		__is_send_all.value = value
	
	var __robot_id: PBField
	func has_robot_id() -> bool:
		if __robot_id.value != null:
			return true
		return false
	func get_robot_id() -> PackedByteArray:
		return __robot_id.value
	func clear_robot_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__robot_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_robot_id(value : PackedByteArray) -> void:
		__robot_id.value = value
	
	var __mode: PBField
	func has_mode() -> bool:
		if __mode.value != null:
			return true
		return false
	func get_mode() -> int:
		return __mode.value
	func clear_mode() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_mode(value : int) -> void:
		__mode.value = value
	
	var __enemy_id: PBField
	func has_enemy_id() -> bool:
		if __enemy_id.value != null:
			return true
		return false
	func get_enemy_id() -> int:
		return __enemy_id.value
	func clear_enemy_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__enemy_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_enemy_id(value : int) -> void:
		__enemy_id.value = value
	
	var __ascii: PBField
	func has_ascii() -> bool:
		if __ascii.value != null:
			return true
		return false
	func get_ascii() -> int:
		return __ascii.value
	func clear_ascii() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ascii.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ascii(value : int) -> void:
		__ascii.value = value
	
	var __type: PBField
	func has_type() -> bool:
		if __type.value != null:
			return true
		return false
	func get_type() -> int:
		return __type.value
	func clear_type() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_type(value : int) -> void:
		__type.value = value
	
	var __screen_x: PBField
	func has_screen_x() -> bool:
		if __screen_x.value != null:
			return true
		return false
	func get_screen_x() -> int:
		return __screen_x.value
	func clear_screen_x() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__screen_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_screen_x(value : int) -> void:
		__screen_x.value = value
	
	var __screen_y: PBField
	func has_screen_y() -> bool:
		if __screen_y.value != null:
			return true
		return false
	func get_screen_y() -> int:
		return __screen_y.value
	func clear_screen_y() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__screen_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_screen_y(value : int) -> void:
		__screen_y.value = value
	
	var __map_x: PBField
	func has_map_x() -> bool:
		if __map_x.value != null:
			return true
		return false
	func get_map_x() -> float:
		return __map_x.value
	func clear_map_x() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__map_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_map_x(value : float) -> void:
		__map_x.value = value
	
	var __map_y: PBField
	func has_map_y() -> bool:
		if __map_y.value != null:
			return true
		return false
	func get_map_y() -> float:
		return __map_y.value
	func clear_map_y() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__map_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_map_y(value : float) -> void:
		__map_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RaderInfoToClient:
	func _init():
		var service
		
		__target_robot_id = PBField.new("target_robot_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_robot_id
		data[__target_robot_id.tag] = service
		
		__target_pos_x = PBField.new("target_pos_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __target_pos_x
		data[__target_pos_x.tag] = service
		
		__target_pos_y = PBField.new("target_pos_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __target_pos_y
		data[__target_pos_y.tag] = service
		
		__torward_angle = PBField.new("torward_angle", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __torward_angle
		data[__torward_angle.tag] = service
		
		__is_high_light = PBField.new("is_high_light", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __is_high_light
		data[__is_high_light.tag] = service
		
	var data = {}
	
	var __target_robot_id: PBField
	func has_target_robot_id() -> bool:
		if __target_robot_id.value != null:
			return true
		return false
	func get_target_robot_id() -> int:
		return __target_robot_id.value
	func clear_target_robot_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__target_robot_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_robot_id(value : int) -> void:
		__target_robot_id.value = value
	
	var __target_pos_x: PBField
	func has_target_pos_x() -> bool:
		if __target_pos_x.value != null:
			return true
		return false
	func get_target_pos_x() -> float:
		return __target_pos_x.value
	func clear_target_pos_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__target_pos_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_target_pos_x(value : float) -> void:
		__target_pos_x.value = value
	
	var __target_pos_y: PBField
	func has_target_pos_y() -> bool:
		if __target_pos_y.value != null:
			return true
		return false
	func get_target_pos_y() -> float:
		return __target_pos_y.value
	func clear_target_pos_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__target_pos_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_target_pos_y(value : float) -> void:
		__target_pos_y.value = value
	
	var __torward_angle: PBField
	func has_torward_angle() -> bool:
		if __torward_angle.value != null:
			return true
		return false
	func get_torward_angle() -> float:
		return __torward_angle.value
	func clear_torward_angle() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__torward_angle.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_torward_angle(value : float) -> void:
		__torward_angle.value = value
	
	var __is_high_light: PBField
	func has_is_high_light() -> bool:
		if __is_high_light.value != null:
			return true
		return false
	func get_is_high_light() -> int:
		return __is_high_light.value
	func clear_is_high_light() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__is_high_light.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_is_high_light(value : int) -> void:
		__is_high_light.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CustomByteBlock:
	func _init():
		var service
		
		__data = PBField.new("data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __data
		data[__data.tag] = service
		
	var data = {}
	
	var __data: PBField
	func has_data() -> bool:
		if __data.value != null:
			return true
		return false
	func get_data() -> PackedByteArray:
		return __data.value
	func clear_data() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_data(value : PackedByteArray) -> void:
		__data.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AssemblyCommand:
	func _init():
		var service
		
		__operation = PBField.new("operation", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __operation
		data[__operation.tag] = service
		
		__difficulty = PBField.new("difficulty", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __difficulty
		data[__difficulty.tag] = service
		
	var data = {}
	
	var __operation: PBField
	func has_operation() -> bool:
		if __operation.value != null:
			return true
		return false
	func get_operation() -> int:
		return __operation.value
	func clear_operation() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__operation.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_operation(value : int) -> void:
		__operation.value = value
	
	var __difficulty: PBField
	func has_difficulty() -> bool:
		if __difficulty.value != null:
			return true
		return false
	func get_difficulty() -> int:
		return __difficulty.value
	func clear_difficulty() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__difficulty.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_difficulty(value : int) -> void:
		__difficulty.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TechCoreMotionStateSync:
	func _init():
		var service
		
		__maximum_difficulty_level = PBField.new("maximum_difficulty_level", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __maximum_difficulty_level
		data[__maximum_difficulty_level.tag] = service
		
		__status = PBField.new("status", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __status
		data[__status.tag] = service
		
	var data = {}
	
	var __maximum_difficulty_level: PBField
	func has_maximum_difficulty_level() -> bool:
		if __maximum_difficulty_level.value != null:
			return true
		return false
	func get_maximum_difficulty_level() -> int:
		return __maximum_difficulty_level.value
	func clear_maximum_difficulty_level() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__maximum_difficulty_level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_maximum_difficulty_level(value : int) -> void:
		__maximum_difficulty_level.value = value
	
	var __status: PBField
	func has_status() -> bool:
		if __status.value != null:
			return true
		return false
	func get_status() -> int:
		return __status.value
	func clear_status() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_status(value : int) -> void:
		__status.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotPerformanceSelectionCommand:
	func _init():
		var service
		
		__shooter = PBField.new("shooter", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __shooter
		data[__shooter.tag] = service
		
		__chassis = PBField.new("chassis", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __chassis
		data[__chassis.tag] = service
		
	var data = {}
	
	var __shooter: PBField
	func has_shooter() -> bool:
		if __shooter.value != null:
			return true
		return false
	func get_shooter() -> int:
		return __shooter.value
	func clear_shooter() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__shooter.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_shooter(value : int) -> void:
		__shooter.value = value
	
	var __chassis: PBField
	func has_chassis() -> bool:
		if __chassis.value != null:
			return true
		return false
	func get_chassis() -> int:
		return __chassis.value
	func clear_chassis() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__chassis.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_chassis(value : int) -> void:
		__chassis.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RobotPerformanceSelectionSync:
	func _init():
		var service
		
		__shooter = PBField.new("shooter", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __shooter
		data[__shooter.tag] = service
		
		__chassis = PBField.new("chassis", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __chassis
		data[__chassis.tag] = service
		
	var data = {}
	
	var __shooter: PBField
	func has_shooter() -> bool:
		if __shooter.value != null:
			return true
		return false
	func get_shooter() -> int:
		return __shooter.value
	func clear_shooter() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__shooter.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_shooter(value : int) -> void:
		__shooter.value = value
	
	var __chassis: PBField
	func has_chassis() -> bool:
		if __chassis.value != null:
			return true
		return false
	func get_chassis() -> int:
		return __chassis.value
	func clear_chassis() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__chassis.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_chassis(value : int) -> void:
		__chassis.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class HeroDeployModeEventCommand:
	func _init():
		var service
		
		__mode = PBField.new("mode", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __mode
		data[__mode.tag] = service
		
	var data = {}
	
	var __mode: PBField
	func has_mode() -> bool:
		if __mode.value != null:
			return true
		return false
	func get_mode() -> int:
		return __mode.value
	func clear_mode() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_mode(value : int) -> void:
		__mode.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DeployModeStatusSync:
	func _init():
		var service
		
		__status = PBField.new("status", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __status
		data[__status.tag] = service
		
	var data = {}
	
	var __status: PBField
	func has_status() -> bool:
		if __status.value != null:
			return true
		return false
	func get_status() -> int:
		return __status.value
	func clear_status() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_status(value : int) -> void:
		__status.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RuneActivateCommand:
	func _init():
		var service
		
		__activate = PBField.new("activate", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __activate
		data[__activate.tag] = service
		
	var data = {}
	
	var __activate: PBField
	func has_activate() -> bool:
		if __activate.value != null:
			return true
		return false
	func get_activate() -> int:
		return __activate.value
	func clear_activate() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__activate.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_activate(value : int) -> void:
		__activate.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RuneStatusSync:
	func _init():
		var service
		
		__rune_status = PBField.new("rune_status", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __rune_status
		data[__rune_status.tag] = service
		
		__activated_arms = PBField.new("activated_arms", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __activated_arms
		data[__activated_arms.tag] = service
		
		__average_rings = PBField.new("average_rings", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __average_rings
		data[__average_rings.tag] = service
		
	var data = {}
	
	var __rune_status: PBField
	func has_rune_status() -> bool:
		if __rune_status.value != null:
			return true
		return false
	func get_rune_status() -> int:
		return __rune_status.value
	func clear_rune_status() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__rune_status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_rune_status(value : int) -> void:
		__rune_status.value = value
	
	var __activated_arms: PBField
	func has_activated_arms() -> bool:
		if __activated_arms.value != null:
			return true
		return false
	func get_activated_arms() -> int:
		return __activated_arms.value
	func clear_activated_arms() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__activated_arms.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_activated_arms(value : int) -> void:
		__activated_arms.value = value
	
	var __average_rings: PBField
	func has_average_rings() -> bool:
		if __average_rings.value != null:
			return true
		return false
	func get_average_rings() -> int:
		return __average_rings.value
	func clear_average_rings() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__average_rings.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_average_rings(value : int) -> void:
		__average_rings.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SentinelStatusSync:
	func _init():
		var service
		
		__posture_id = PBField.new("posture_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __posture_id
		data[__posture_id.tag] = service
		
		__is_weakened = PBField.new("is_weakened", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_weakened
		data[__is_weakened.tag] = service
		
	var data = {}
	
	var __posture_id: PBField
	func has_posture_id() -> bool:
		if __posture_id.value != null:
			return true
		return false
	func get_posture_id() -> int:
		return __posture_id.value
	func clear_posture_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__posture_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_posture_id(value : int) -> void:
		__posture_id.value = value
	
	var __is_weakened: PBField
	func has_is_weakened() -> bool:
		if __is_weakened.value != null:
			return true
		return false
	func get_is_weakened() -> bool:
		return __is_weakened.value
	func clear_is_weakened() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__is_weakened.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_weakened(value : bool) -> void:
		__is_weakened.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DartCommand:
	func _init():
		var service
		
		__target_id = PBField.new("target_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_id
		data[__target_id.tag] = service
		
		__open = PBField.new("open", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __open
		data[__open.tag] = service
		
	var data = {}
	
	var __target_id: PBField
	func has_target_id() -> bool:
		if __target_id.value != null:
			return true
		return false
	func get_target_id() -> int:
		return __target_id.value
	func clear_target_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__target_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_id(value : int) -> void:
		__target_id.value = value
	
	var __open: PBField
	func has_open() -> bool:
		if __open.value != null:
			return true
		return false
	func get_open() -> bool:
		return __open.value
	func clear_open() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__open.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_open(value : bool) -> void:
		__open.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DartSelectTargetStatusSync:
	func _init():
		var service
		
		__target_id = PBField.new("target_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_id
		data[__target_id.tag] = service
		
		__open = PBField.new("open", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __open
		data[__open.tag] = service
		
	var data = {}
	
	var __target_id: PBField
	func has_target_id() -> bool:
		if __target_id.value != null:
			return true
		return false
	func get_target_id() -> int:
		return __target_id.value
	func clear_target_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__target_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_id(value : int) -> void:
		__target_id.value = value
	
	var __open: PBField
	func has_open() -> bool:
		if __open.value != null:
			return true
		return false
	func get_open() -> bool:
		return __open.value
	func clear_open() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__open.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_open(value : bool) -> void:
		__open.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GuardCtrlCommand:
	func _init():
		var service
		
		__command_id = PBField.new("command_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __command_id
		data[__command_id.tag] = service
		
	var data = {}
	
	var __command_id: PBField
	func has_command_id() -> bool:
		if __command_id.value != null:
			return true
		return false
	func get_command_id() -> int:
		return __command_id.value
	func clear_command_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__command_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_command_id(value : int) -> void:
		__command_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GuardCtrlResult:
	func _init():
		var service
		
		__command_id = PBField.new("command_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __command_id
		data[__command_id.tag] = service
		
		__result_code = PBField.new("result_code", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __result_code
		data[__result_code.tag] = service
		
	var data = {}
	
	var __command_id: PBField
	func has_command_id() -> bool:
		if __command_id.value != null:
			return true
		return false
	func get_command_id() -> int:
		return __command_id.value
	func clear_command_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__command_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_command_id(value : int) -> void:
		__command_id.value = value
	
	var __result_code: PBField
	func has_result_code() -> bool:
		if __result_code.value != null:
			return true
		return false
	func get_result_code() -> int:
		return __result_code.value
	func clear_result_code() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__result_code.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_result_code(value : int) -> void:
		__result_code.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AirSupportCommand:
	func _init():
		var service
		
		__command_id = PBField.new("command_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __command_id
		data[__command_id.tag] = service
		
	var data = {}
	
	var __command_id: PBField
	func has_command_id() -> bool:
		if __command_id.value != null:
			return true
		return false
	func get_command_id() -> int:
		return __command_id.value
	func clear_command_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__command_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_command_id(value : int) -> void:
		__command_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AirSupportStatusSync:
	func _init():
		var service
		
		__airsupport_status = PBField.new("airsupport_status", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __airsupport_status
		data[__airsupport_status.tag] = service
		
		__left_time = PBField.new("left_time", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __left_time
		data[__left_time.tag] = service
		
		__cost_coins = PBField.new("cost_coins", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __cost_coins
		data[__cost_coins.tag] = service
		
	var data = {}
	
	var __airsupport_status: PBField
	func has_airsupport_status() -> bool:
		if __airsupport_status.value != null:
			return true
		return false
	func get_airsupport_status() -> int:
		return __airsupport_status.value
	func clear_airsupport_status() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__airsupport_status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_airsupport_status(value : int) -> void:
		__airsupport_status.value = value
	
	var __left_time: PBField
	func has_left_time() -> bool:
		if __left_time.value != null:
			return true
		return false
	func get_left_time() -> int:
		return __left_time.value
	func clear_left_time() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__left_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_left_time(value : int) -> void:
		__left_time.value = value
	
	var __cost_coins: PBField
	func has_cost_coins() -> bool:
		if __cost_coins.value != null:
			return true
		return false
	func get_cost_coins() -> int:
		return __cost_coins.value
	func clear_cost_coins() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__cost_coins.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_cost_coins(value : int) -> void:
		__cost_coins.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
