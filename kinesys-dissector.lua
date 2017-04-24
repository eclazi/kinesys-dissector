kinesys_proto = Proto("kinesys", "Kinesys")

udp_table = DissectorTable.get("udp.port")

proto_strs = {  "Degree’s are specified to 0 decimal places",  "Degree’s are specified to 2 decimal places" }	
axis_strs = {"X", "Y", "Z", "Pan", "Tilt", "Rotate"}

function kinesys_proto.dissector(buffer, pinfo, tree)

	subtree = tree:add(kinesys_proto, buffer(), "Kinesys Media Server Packet")
	pinfo.cols.protocol = "Kinesys"

	id = buffer(0, 12):string()
	subtree:add(buffer(0, 12), string.format("ID: %s", id))

	opcode_str = "Invalid"
	opcode = buffer(12, 2):uint()
	if (opcode == 3) then
		opcode_str = "Multicast"
	end
	subtree:add(buffer(12, 2), string.format("OpCode: 0x%04x %s", opcode, opcode_str))

	protver_str = "Invalid"
	protver = buffer(14, 2):uint()
	if protver < 2 then
        protver_str = proto_strs[protver + 1]
	end
	subtree:add(buffer(14, 2), string.format("ProtVer: 0x%04x %s", protver, protver_str))

	minprotver = buffer(16, 2):uint()
	subtree:add(buffer(16, 2), string.format("MinProtVer: 0x%04x", minprotver))

	frameid = buffer(18, 2):le_uint()
	subtree:add(buffer(18, 2), string.format("Frame ID: %d", frameid))

	nmsgs = buffer(20, 1):uint()
	subtree:add(buffer(20, 1), string.format("NumDataMsgs: %d", nmsgs))

	subtree:add(buffer(21, 1), "Pad")
	subtree:add(buffer(22, 8), "Spare")

	message_tree = subtree:add(buffer(30, buffer:len() - 30), "Messages")
	for i = 0, nmsgs - 1 do
		offset = 30 + i * 10

		axisid = buffer(offset, 2):uint()
		paramid = axisid % 100
		constructid = (axisid - paramid) / 100

		paramstr = "Invalid"
		if (paramid < 7) then
			paramstr = axis_strs[paramid + 1]
		end

		is_position = paramid < 4

		value = buffer(offset + 2, 4):int()
		value_str = ""

		if is_position then
			value_str = string.format("%d mm", value)
		else
			value_str = string.format("%d °", value)		
		end

		speed = buffer(offset + 6, 2):int()
		speed_str = ""
		if is_position then
			speed_str = string.format("%d mm/s", value)
		else
			speed_str = string.format("%d °/s", value)		
		end

		message = message_tree:add(buffer(offset, 10), string.format("Construct %d %s" , constructid, paramstr))
		message:add(buffer(offset, 2), string.format("AxisID: %d", axisid))
		message:add(buffer(offset + 2, 4), string.format("Value: %s", value_str))
		message:add(buffer(offset + 6, 2), string.format("Speed: %s", speed_str))

		errors = buffer(offset + 8, 2):int()
		message:add(buffer(offset + 8, 2), string.format("Errors: %d", errors))
	end
end
udp_table:add(6061, kinesys_proto)
