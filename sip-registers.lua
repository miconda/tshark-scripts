-- List REGISTER transactions
-- * details for first received REGISTER
-- * details for last response sent to the origin of the REGISTER
-- * the key is 'Call-Id::CSeq-Number'

debug = tonumber(os.getenv('DEBUG') or "0")
if debug == 1 then
	print("-- starting")
end

do
	sipregs = {}
	local sip_request_line_f = Field.new("sip.Request-Line")
	local sip_status_code_f = Field.new("sip.Status-Code")
	local sip_call_id_f = Field.new("sip.Call-ID")
	local sip_cseq_method_f = Field.new("sip.CSeq.method")
	local sip_cseq_number_f = Field.new("sip.CSeq.seq")
	local sip_expires_f = Field.new("sip.Expires")
	local sip_to_user_f = Field.new("sip.to.user")

	local function register_listener()
		local tap = Listener.new(nil, "(sip.CSeq.method == REGISTER)")
		function tap.packet(pinfo, tvb, tapinfo)
			local sip_request_line = tostring(sip_request_line_f() or "none")
			local sip_status_code = tostring(sip_status_code_f() or "none")
			local sip_call_id = tostring(sip_call_id_f())
			local sip_cseq_method = tostring(sip_cseq_method_f())
			local src_addr = tostring(pinfo.src) .. ":" .. tostring(pinfo.src_port)
			local dst_addr = tostring(pinfo.dst) .. ":" .. tostring(pinfo.dst_port)
			local sip_cseq_number = tostring(sip_cseq_number_f())
			local sip_expires = tonumber(tostring(sip_expires_f() or "-1"))
			local sip_to_user = tostring(sip_to_user_f())
			local regkey = sip_call_id .. "::" .. sip_cseq_number

			if sip_request_line ~= "none" then
				if sipregs[regkey] == nil then
					sipregs[regkey] = {}
				end
				if sipregs[regkey]["REGISTER_FRAMENO"] == nil then
					sipregs[regkey]["REGISTER_FRAMENO"] = pinfo.number
					sipregs[regkey]["REGISTER_TIME"] = pinfo.abs_ts
					sipregs[regkey]["REGISTER_DATE"] = tostring(os.date('%Y-%m-%d %H:%M:%S', sipregs[regkey]["REGISTER_TIME"]))
					sipregs[regkey]["REGISTER_SRC"] = src_addr
					sipregs[regkey]["REGISTER_DST"] = dst_addr
					sipregs[regkey]["REGISTER_EXPIRES"] = sip_expires
					sipregs[regkey]["REGISTER_TOUSER"] = sip_to_user
				end
			end
			if sip_status_code ~= "none" and sipregs[regkey] ~= nil
					and sipregs[regkey]["REGISTER_SRC"] == dst_addr then
				sipregs[regkey]["REPLY_FRAMENO"] = pinfo.number
				sipregs[regkey]["RREPLY_CODE"] = sip_status_code
				sipregs[regkey]["RREPLY_TIME"] = pinfo.abs_ts
				sipregs[regkey]["REPLY_SRC"] = src_addr
				sipregs[regkey]["REPLY_DST"] = dst_addr
			end
		end
		function print_j(tbl, indent)
			indent = indent or '    '
			io.write("{\n")
			local l = 0
			local n = 0
			local skeys = {}
			for k in pairs(tbl) do
				table.insert(skeys, k)
				n = n + 1
			end
			table.sort(skeys)
			for _, k in pairs(skeys) do
				v = tbl[k]
				io.write(indent .. string.format("%q", k) .. ": ")
				if type(v) == "table" then
					print_j(v, indent .. '    ')
				else
					if type(v) == "number" then
						io.write(tostring(v))
					else
						io.write(string.format("%q", tostring(v)))
					end
					t = 0
				end
				l = l + 1
				if l == n then
					io.write("\n")
				else
					io.write(",\n")
				end
			end
			io.write(string.sub(indent, 1, -5) .. "}")
		end
		function tap.draw()
			if debug == 1 then
				print("-- ready")
			end
			print_j(sipregs)
			print()
			if debug == 1 then
				print("-- done")
			end
		end
		function tap.reset()
			if debug == 1 then
				print("-- finished")
			end
		end
	end
	register_listener()
end
