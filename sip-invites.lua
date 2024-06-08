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

	local function register_listener()
		local tap = Listener.new(nil, "(sip.CSeq.method == INVITE)")
		function tap.packet(pinfo, tvb, tapinfo)
			local sip_request_line = tostring(sip_request_line_f() or "none")
			local sip_status_code = tostring(sip_status_code_f() or "none")
			local sip_call_id = tostring(sip_call_id_f())
			local sip_cseq_method = tostring(sip_cseq_method_f())
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
			print("-- ready")
			print_r(sipcalls)
			print("-- done")
		end
		function tap.reset()
			print("-- finished")
		end
	end
	register_listener()
end
