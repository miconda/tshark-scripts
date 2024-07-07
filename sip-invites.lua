-- List INVITE transactions
-- * details for first received INVITE
-- * details for last response sent to the origin of the INVITE

print("-- starting")

do
	sipcalls = {}
	local sip_request_line_f = Field.new("sip.Request-Line")
	local sip_status_code_f = Field.new("sip.Status-Code")
	local sip_call_id_f = Field.new("sip.Call-ID")
	local sip_cseq_method_f = Field.new("sip.CSeq.method")
	local sip_user_agent_f = Field.new("sip.User-Agent")

	local function register_listener()
		local tap = Listener.new(nil, "(sip.CSeq.method == INVITE)")
		function tap.packet(pinfo, tvb, tapinfo)
			local sip_request_line = tostring(sip_request_line_f() or "none")
			local sip_status_code = tostring(sip_status_code_f() or "none")
			local sip_call_id = tostring(sip_call_id_f())
			local sip_cseq_method = tostring(sip_cseq_method_f())
			local sip_user_agent = tostring(sip_user_agent_f())
			local src_addr = tostring(pinfo.src) .. ":" .. tostring(pinfo.src_port)
			local dst_addr = tostring(pinfo.dst) .. ":" .. tostring(pinfo.dst_port)

			if sip_request_line ~= "none" then
				if sipcalls[sip_call_id] == nil then
					sipcalls[sip_call_id] = {}
				end
				if sipcalls[sip_call_id]["INVITE_FRAMENO"] == nil then
					sipcalls[sip_call_id]["INVITE_FRAMENO"] = pinfo.number
					sipcalls[sip_call_id]["INVITE_TIME"] = pinfo.abs_ts
					sipcalls[sip_call_id]["INVITE_SRC"] = src_addr
					sipcalls[sip_call_id]["INVITE_DST"] = dst_addr
					sipcalls[sip_call_id]["INVITE_USERAGENT"] = sip_user_agent
				end
			end
			if sip_status_code ~= "none" and sipcalls[sip_call_id] ~= nil
					and sipcalls[sip_call_id]["INVITE_SRC"] == dst_addr then
				sipcalls[sip_call_id]["REPLY_FRAMENO"] = pinfo.number
				sipcalls[sip_call_id]["RREPLY_CODE"] = sip_status_code
				sipcalls[sip_call_id]["RREPLY_TIME"] = pinfo.abs_ts
				sipcalls[sip_call_id]["REPLY_SRC"] = src_addr
				sipcalls[sip_call_id]["REPLY_DST"] = dst_addr
			end
		end
		function print_j(tbl, indent)
			indent = indent or '    '
			io.write("{\n")
			local l = 0
			local t = 0
			for k, v in pairs(tbl) do
				if l == 1 then
					io.write(",\n")
				end
				io.write(indent .. string.format("%q", k) .. ": ")
				if type(v) == "table" then
					print_j(v, indent .. '    ')
					io.write("\n")
					t = 1
				else
					if type(v) == "number" then
						io.write(tostring(v))
					else
						io.write(string.format("%q", tostring(v)))
					end
					t = 0
				end
				l = 1
			end
			if t == 0 then
				io.write("\n")
			end
			io.write(string.sub(indent, 1, -5) .. "}")
		end
		function tap.draw()
			print("-- ready")
			print_j(sipcalls)
			print()
			print("-- done")
		end
		function tap.reset()
			print("-- finished")
		end
	end
	register_listener()
end
