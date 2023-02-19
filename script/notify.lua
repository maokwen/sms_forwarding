local notify = {}

--你的wifi名称和密码
local wifiName = ""
local wifiPasswd = ""
local pushURL = ""

--缓存消息
local buff = {}

--来新消息了
function notify.add(phone,data)
    log.info("notify","got sms",phone,data)
    table.insert(buff,{phone,data})
    sys.publish("SMS_ADD")--推个事件
end


sys.taskInit(function()
    sys.wait(1000)
    wlan.init()--初始化wifi
    wlan.connect(wifiName, wifiPasswd)
    log.info("wlan", "wait for IP_READY")
    sys.waitUntil("IP_READY", 30000)
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

                local data = pdu.ucs2_utf8(sms[2])
                local msg = {
                    from = sms[1],
                    text = data
                }

                log.info("notify","send to server",data)
                code, h, body = http.request(
                        "POST",
                        pushURL,
                        {["Content-Type"] = "application/json"},
                        json.encode(msg)
                    ).wait()
                log.info("notify","pushed sms notify",code,h,body,sms[1])
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
