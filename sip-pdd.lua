-- List post dial delay (PDD) for INVITE transactions
-- * betweend first received INVITE and last sent 180
-- * betweend first received INVITE and last sent 183

debug = tonumber(os.getenv('DEBUG') or "0")
if debug == 1 then
	print("-- starting sip-pdd.lua script")
end

do
	sipcalls = {}
	local sip_request_line_f = Field.new("sip.Request-Line")
	local sip_status_code_f = Field.new("sip.Status-Code")
	local sip_call_id_f = Field.new("sip.Call-ID")
	local sip_cseq_method_f = Field.new("sip.CSeq.method")
	local sip_cseq_number_f = Field.new("sip.CSeq.seq")

	local function register_listener()
		local tap = Listener.new(nil, "(sip.CSeq.method == INVITE)")
		function tap.packet(pinfo, tvb, tapinfo)
			local sip_request_line = tostring(sip_request_line_f() or "none")
			local sip_status_code = tostring(sip_status_code_f() or "none")
			local sip_call_id = tostring(sip_call_id_f())
			local sip_cseq_method = tostring(sip_cseq_method_f())
			local sip_cseq_number = tostring(sip_cseq_number_f())
			local src_addr = tostring(pinfo.src) .. ":" .. tostring(pinfo.src_port)
			local dst_addr = tostring(pinfo.dst) .. ":" .. tostring(pinfo.dst_port)

			if debug == 1 then
				print("======= call-id: " .. sip_call_id)
				print("        request-line: " .. sip_request_line)
				print("        status-code: " .. sip_status_code)
				print("        method: " .. sip_cseq_method)
				print("        cseq-number: " .. sip_cseq_number)
				print("        time: " .. tostring(pinfo.abs_ts))
				print("        src-addr: " .. src_addr)
				print("        dst-addr: " .. dst_addr)
				print("^^^^^^^ call-id: " .. sip_call_id)
			end

			local invkey = sip_call_id .. "::" .. sip_cseq_number
			if sip_request_line ~= "none" then
				if sipcalls[invkey] == nil then
					sipcalls[invkey] = {}
				end
				if sipcalls[invkey]["INVITE_FRAMENO"] == nil then
					sipcalls[invkey]["INVITE_FRAMENO"] = pinfo.number
					sipcalls[invkey]["INVITE_TIME"] = pinfo.abs_ts
					sipcalls[invkey]["INVITE_SRC"] = src_addr
					sipcalls[invkey]["INVITE_DST"] = dst_addr
				end
			end
			if sip_status_code ~= "none" and sipcalls[invkey] ~= nil
					and sipcalls[invkey]["INVITE_SRC"] == dst_addr then
				local rkey = "R" .. sip_status_code
				if sipcalls[invkey][rkey .. "F_FRAMENO"] == nil then
					sipcalls[invkey][rkey .. "F_FRAMENO"] = pinfo.number
					sipcalls[invkey][rkey .. "F_TIME"] = pinfo.abs_ts
					sipcalls[invkey][rkey .. "F_SRC"] = src_addr
					sipcalls[invkey][rkey .. "F_DST"] = dst_addr
				end
				sipcalls[invkey][rkey .. "L_FRAMENO"] = pinfo.number
				sipcalls[invkey][rkey .. "L_TIME"] = pinfo.abs_ts
				sipcalls[invkey][rkey .. "L_SRC"] = src_addr
				sipcalls[invkey][rkey .. "L_DST"] = dst_addr
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
			if debug == 1 then
				print_j(sipcalls)
				print()
			end
			if debug == 1 then
				print("-- processing")
			end
			local pddtbl = {}
			local rplcodes = {"100", "180", "183", "200"}
			for k,v in pairs(sipcalls) do
				pddtbl[k] = {}
				for _, r in pairs(rplcodes) do
					local rkey = "R" .. r
					if sipcalls[k][rkey .. "F_TIME"] ~= nil then
						pdd = tonumber(string.format("%.4f", sipcalls[k][rkey .. "F_TIME"] -
								sipcalls[k]["INVITE_TIME"]))
						pddtbl[k]["PDD" .. r .."F"] = pdd
					end
					if sipcalls[k][rkey .. "L_TIME"] ~= nil then
						pdd = tonumber(string.format("%.4f", sipcalls[k][rkey .. "L_TIME"] -
								sipcalls[k]["INVITE_TIME"]))
						pddtbl[k]["PDD" .. r .."L"] = pdd
					end
				end
			end
			print_j(pddtbl)
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
