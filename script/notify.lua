local notify = {}

--你的wifi名称和密码,仅2.4G
local wifis = {}
table.insert(wifis, {name = "", password = ""})
-- 多个 wifi 继续使用 table.insert 添加，会逐个尝试

-- 推送URL
local pushURL = ""

--自定义push链接
local barkJumpURL = ""

--短信接收指令的标记（密码）
--[[
目前支持命令（[cmdTag]表示你的tag）
C[cmdTag]REBOOT：重启
C[cmdTag]SEND[手机号][空格][短信内容]：主动发短信
]]
local cmdTag = "1234"

--缓存消息
local buff = {}

--来新消息了
function notify.add(phone,data)
    data = pdu.ucs2_utf8(data)--转码
    log.info("notify","got sms",phone,data)
    --匹配上了指令
    if data:find("C"..cmdTag) == 1 then
        log.info("cmd","matched cmd")
        if data:find("C"..cmdTag.."REBOOT") == 1 then
            sys.timerStart(rtos.reboot,10000)
            data = "reboot command done"
        elseif data:find("C"..cmdTag.."SEND") == 1 then
            local _,_,phone,text = data:find("C"..cmdTag.."SEND(%d+) +(.+)")
            if phone and text then
                log.info("cmd","cmd send sms",phone,text)
                local d,len = pdu.encodePDU(phone,text)
                if d and len then
                    air780.write("AT+CMGS="..len.."\r\n")
                    local r = sys.waitUntil("AT_SEND_SMS", 5000)
                    if r then
                        air780.write(d,true)
                        sys.wait(500)
                        air780.write(string.char(0x1A),true)
                        data = "send sms at command done"
                    else
                        data = "send sms at command error!"
                    end
                end
            end
        end
    end
    table.insert(buff,{phone,data})
    sys.publish("SMS_ADD")--推个事件
end


sys.taskInit(function()
    sys.wait(1000)
    wlan.init()--初始化wifi
    for i, wifi in ipairs(wifis) do
        log.info("wlan", "trying wifi #".. i .. " " .. wifi.name)
        wlan.connect(wifi.name, wifi.password)
        log.info("wlan", "wait for IP_READY")
        sys.waitUntil("IP_READY", 30*1000)
        if wlan.ready() then
            break
        end
        wlan.disconnect()
        wlan.init()
        sys.wait(5*1000)
    end
    log.info("wlan", "wait for MODULE_READY")
    sys.waitUntil("MODULE_READY", 3000)
    print("gc1",collectgarbage("count"))
    if wlan.ready() then
        log.info("wlan", "ready !!")
        while true do
            print("gc2",collectgarbage("count"))
            while #buff > 0 do--把消息读完
                collectgarbage("collect")--防止内存不足
                local sms = table.remove(buff,1)
                local code,h, body


                    log.info("notify","send to push server",data)
                    code, h, body = http.request(
                            "POST",
                            pushURL,
                            {["Content-Type"] = "application/json"},
                            json.encode(msg)
                        ).wait()
                    log.info("notify","pushed sms notify", code, h, body, sms[1])
                end
                
                collectgarbage("collect")
                if #barkURL > 0 and sms[1] ~= "10086" then
                    local msg = {
                        title = "sms: " .. sms[1],
                        body = data,
                        device_key = barkDeviceKey
                    }

                    log.info("notify","send to bark server",data)
                    code, h, body = http.request(
                            "POST",
                            barkURL,
                            {["Content-Type"] = "application/json"},
                            json.encode(msg)
                        ).wait()
                    log.info("notify","pushed sms notify", code, h, body, sms[1])
                end
            end
            log.info("notify","wait for a new sms~")
            print("gc3",collectgarbage("count"))
            sys.waitUntil("SMS_ADD")
        end
    else
        print("wlan NOT ready!!!!")
        rtos.reboot()
    end
end)



return notify
