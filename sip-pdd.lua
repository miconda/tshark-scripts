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

	local function register_listener()
		local tap = Listener.new(nil, "(sip.CSeq.method == INVITE)")
		function tap.packet(pinfo, tvb, tapinfo)
			local sip_request_line = tostring(sip_request_line_f() or "none")
			local sip_status_code = tostring(sip_status_code_f() or "none")
			local sip_call_id = tostring(sip_call_id_f())
			local sip_cseq_method = tostring(sip_cseq_method_f())
			local src_addr = tostring(pinfo.src) .. ":" .. tostring(pinfo.src_port)
			local dst_addr = tostring(pinfo.dst) .. ":" .. tostring(pinfo.dst_port)

			if debug == 1 then
				print("======= call-id: " .. sip_call_id)
				print("        request-line: " .. sip_request_line)
				print("        status-code: " .. sip_status_code)
				print("        method: " .. sip_cseq_method)
				print("        time: " .. tostring(pinfo.abs_ts))
				print("        src-addr: " .. src_addr)
				print("        dst-addr: " .. dst_addr)
				print("^^^^^^^ call-id: " .. sip_call_id)
			end

			if sip_request_line ~= "none" then
				if sipcalls[sip_call_id] == nil then
					sipcalls[sip_call_id] = {}
				end
				if sipcalls[sip_call_id]["INVITE_FRAMENO"] == nil then
					sipcalls[sip_call_id]["INVITE_FRAMENO"] = pinfo.number
					sipcalls[sip_call_id]["INVITE_TIME"] = pinfo.abs_ts
					sipcalls[sip_call_id]["INVITE_SRC"] = src_addr
					sipcalls[sip_call_id]["INVITE_DST"] = dst_addr
				end
			end
			if sip_status_code == "180" and sipcalls[sip_call_id] ~= nil then
				sipcalls[sip_call_id]["R180_FRAMENO"] = pinfo.number
				sipcalls[sip_call_id]["R180_TIME"] = pinfo.abs_ts
				sipcalls[sip_call_id]["R180_SRC"] = src_addr
				sipcalls[sip_call_id]["R180_DST"] = dst_addr
			end
			if sip_status_code == "183" and sipcalls[sip_call_id] ~= nil then
				sipcalls[sip_call_id]["R183_FRAMENO"] = pinfo.number
				sipcalls[sip_call_id]["R183_TIME"] = pinfo.abs_ts
				sipcalls[sip_call_id]["R183_SRC"] = src_addr
				sipcalls[sip_call_id]["R183_DST"] = dst_addr
			end
		end
		function print_r (t, indent, done)
			done = done or {}
			indent = indent or ''
			local nextIndent -- Storage for next indentation value
			for key, value in pairs (t) do
				if type (value) == "table" and not done [value] then
					nextIndent = nextIndent or
					(indent .. string.rep(' ',string.len(tostring (key))+2))
					-- Shortcut conditional allocation
					done [value] = true
					print (indent .. "[" .. tostring (key) .. "] => Table {");
					print  (nextIndent .. "{");
					print_r (value, nextIndent .. string.rep(' ',2), done)
					print  (nextIndent .. "}");
				else
					print  (indent .. "[" .. tostring (key) .. "] => " .. tostring (value).."")
				end
			end
		end
		function tap.draw()
			if debug == 1 then
				print("-- ready")
			end
			if debug == 1 then
				print_r(sipcalls)
			end
			if debug == 1 then
				print("-- processing")
			end
			for k,v in pairs(sipcalls) do
				pdd180 = tonumber(string.format("%.4f", sipcalls[k]["R180_TIME"] - sipcalls[k]["INVITE_TIME"]))
				pdd183 = tonumber(string.format("%.4f", sipcalls[k]["R183_TIME"] - sipcalls[k]["INVITE_TIME"]))
				print("-- pdd180[" .. k .. "] = " .. tostring(pdd180))
				print("-- pdd183[" .. k .. "] = " .. tostring(pdd183))
			end
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
