-- List of calls

debug = tonumber(os.getenv('DEBUG') or "0")
if debug == 1 then
	print("-- starting sip-pdd.lua script")
end

do
	sipcalls = {}
	sipmsgs = {}
	local sip_request_line_f = Field.new("sip.Request-Line")
	local sip_status_code_f = Field.new("sip.Status-Code")
	local sip_call_id_f = Field.new("sip.Call-ID")
	local sip_cseq_method_f = Field.new("sip.CSeq.method")
	local sip_cseq_number_f = Field.new("sip.CSeq.seq")
	local sip_from_tag_f = Field.new("sip.from.tag")
	local sip_to_tag_f = Field.new("sip.to.tag")

	local function register_listener()
		local tap = Listener.new(nil, "(sip.CSeq.method == INVITE) || (sip.CSeq.method == BYE)")
		function tap.packet(pinfo, tvb, tapinfo)
			local sip_request_line = tostring(sip_request_line_f() or "none")
			local sip_status_code = tostring(sip_status_code_f() or "none")
			local sip_call_id = tostring(sip_call_id_f())
			local sip_cseq_method = tostring(sip_cseq_method_f())
			local sip_cseq_number = tostring(sip_cseq_number_f())
			local sip_from_tag = tostring(sip_from_tag_f() or "none")
			local sip_to_tag = tostring(sip_to_tag_f() or "none")
			local src_addr = tostring(pinfo.src) .. ":" .. tostring(pinfo.src_port)
			local dst_addr = tostring(pinfo.dst) .. ":" .. tostring(pinfo.dst_port)

			if debug > 1 then
				print("======= call-id: " .. sip_call_id)
				print("        frame-number: " .. tostring(pinfo.number))
				print("        request-line: " .. sip_request_line)
				print("        status-code: " .. sip_status_code)
				print("        method: " .. sip_cseq_method)
				print("        cseq-number: " .. sip_cseq_number)
				print("        time: " .. tostring(pinfo.abs_ts))
				print("        src-addr: " .. src_addr)
				print("        dst-addr: " .. dst_addr)
				print("^^^^^^^ call-id: " .. sip_call_id)
			end

			local msgkey = sip_call_id .. "::" .. sip_cseq_number .. "::" .. sip_cseq_method
			if sip_request_line ~= "none" then
				if sipmsgs[msgkey] == nil then
					sipmsgs[msgkey] = {}
				end
				local rkey = sip_cseq_method
				if sipmsgs[msgkey][rkey .. "_FRAMENO"] == nil then
					sipmsgs[msgkey][rkey .. "_FRAMENO"] = pinfo.number
					sipmsgs[msgkey][rkey .. "_TIME"] = pinfo.abs_ts
					sipmsgs[msgkey][rkey .. "_FROMTAG"] = sip_from_tag
					sipmsgs[msgkey][rkey .. "_TOTAG"] = sip_to_tag
					sipmsgs[msgkey][rkey .. "_SRC"] = src_addr
					sipmsgs[msgkey][rkey .. "_DST"] = dst_addr
				end
			end
			if sip_status_code ~= "none" and sipmsgs[msgkey] ~= nil
					and sipmsgs[msgkey][sip_cseq_method .. "_SRC"] == dst_addr then
				local rkey = "R" .. sip_status_code
				if sipmsgs[msgkey][rkey .. "F_FRAMENO"] == nil then
					sipmsgs[msgkey][rkey .. "F_FRAMENO"] = pinfo.number
					sipmsgs[msgkey][rkey .. "F_TIME"] = pinfo.abs_ts
					sipmsgs[msgkey][rkey .. "F_FROMTAG"] = sip_from_tag
					sipmsgs[msgkey][rkey .. "F_TOTAG"] = sip_to_tag
					sipmsgs[msgkey][rkey .. "F_SRC"] = src_addr
					sipmsgs[msgkey][rkey .. "F_DST"] = dst_addr
				end
				sipmsgs[msgkey][rkey .. "L_FRAMENO"] = pinfo.number
				sipmsgs[msgkey][rkey .. "L_TIME"] = pinfo.abs_ts
				sipmsgs[msgkey][rkey .. "L_FROMTAG"] = sip_from_tag
				sipmsgs[msgkey][rkey .. "L_TOTAG"] = sip_to_tag
				sipmsgs[msgkey][rkey .. "L_SRC"] = src_addr
				sipmsgs[msgkey][rkey .. "L_DST"] = dst_addr
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
			if debug >= 1 then
				print("-- ready")
			end
			if debug >= 1 then
				print_j(sipmsgs)
				print()
			end
			if debug >= 1 then
				print("-- processing")
			end
			local pddtbl = {}
			local rplcodes = {"100", "180", "183", "200"}
			for k,_ in pairs(sipmsgs) do
				pddtbl[k] = {}
				for _, r in pairs(rplcodes) do
					local qkey = "INVITE"
					if sipmsgs[k]["BYE_FRAMENO"] ~= nil then
						qkey = "BYE";
					end
					local rkey = "R" .. r
					if sipmsgs[k][rkey .. "F_TIME"] ~= nil then
						pdd = tonumber(string.format("%.4f", sipmsgs[k][rkey .. "F_TIME"] -
								sipmsgs[k][qkey .. "_TIME"]))
						pddtbl[k]["PDD" .. r .."F"] = pdd
					end
					if sipmsgs[k][rkey .. "L_TIME"] ~= nil then
						pdd = tonumber(string.format("%.4f", sipmsgs[k][rkey .. "L_TIME"] -
								sipmsgs[k][qkey .. "_TIME"]))
						pddtbl[k]["PDD" .. r .."L"] = pdd
					end
				end
			end
			print_j(pddtbl)
			print()
			if debug >= 1 then
				print("-- done")
			end
		end
		function tap.reset()
			if debug >= 1 then
				print("-- finished")
			end
		end
	end
	register_listener()
end
