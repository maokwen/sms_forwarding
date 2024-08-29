-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "sms_forwarding"
VERSION = "1.0.0"

log.info("main", PROJECT, VERSION)


local pushURL = ""

--pushover配置，用不到可留空
local pushoverApiToken = ""
local pushoverUserKey = ""


--缓存消息
local buff = {}

-- 引入必要的库文件(lua编写), 内部库不需要require
sys = require("sys")
require "sysplus" -- http库需要这个sysplus

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
end
log.info("main", "sms demo")

--检查一下固件版本，防止用户乱刷
do
    local fw = rtos.firmware():lower()--全转成小写
    local ver,bsp = fw:match("luatos%-soc_v(%d-)_(.+)")
    ver = ver and tonumber(ver) or nil
    local r
    if ver and bsp then
        if ver >= 1003 and bsp == "ec618" then
            r = true
        end
    end
    if not r then
        sys.timerLoopStart(function ()
            wdt.feed()
            log.info("警告","固件类型或版本不满足要求，请使用air780(ec618)v1003及以上版本固件。当前："..rtos.firmware())
        end,500)
    end
end

--运营商给的dns经常抽风，手动指定
socket.setDNS(nil, 1, "119.29.29.29")
socket.setDNS(nil, 2, "223.5.5.5")

--订阅短信消息
sys.subscribe("SMS_INC",function(phone,data)
    --来新消息了
    log.info("notify","got sms",phone,data)
    table.insert(buff,{phone,data})
    sys.publish("SMS_ADD")--推个事件
end)

sys.taskInit(function()
    while true do
        print("ww",collectgarbage("count"))
        while #buff > 0 do--把消息读完
            collectgarbage("collect")--防止内存不足
            local sms = table.remove(buff,1)
            local code,h, body
            local data = sms[2]

            local msg = {
                from = sms[1],
                text = data
            }
            local req_body = json.encode(msg)

            log.info("notify", "send to push server", req_body)

            local code, h, resp_body
            for i=1,10 do
                code, h, resp_body = http.request(
                    "POST",
                    pushURL,
                    {["Content-Type"] = "application/json"},
                    req_body
                ).wait()
                log.info("notify","pushed sms notify", code, resp_body, sms[1])
                if code == 200 then
                    break
                end
                sys.wait(5000)
            end

            if #pushoverApiToken > 0 then --Pushover
                log.info("notify","send to Pushover",data)
                local body = {
                    token = pushoverApiToken,
                    user = pushoverUserKey,
                    title = "SMS: "..sms[1],
                    message = data
                }
                local json_body = string.gsub(json.encode(body), "\\b", "\\n") --luatos bug
                --多试几次好了
                for i=1,10 do
                    code, h, body = http.request(
                            "POST",
                            "https://api.pushover.net/1/messages.json",
                            {["Content-Type"] = "application/json; charset=utf-8"},
                            json_body
                        ).wait()
                    log.info("notify","pushed sms notify",code,h,body,sms[1])
                    if code == 200 then
                        break
                    end
                    sys.wait(5000)
                end
            end
        end
        log.info("notify","wait for a new sms~")
        print("zzz",collectgarbage("count"))
        sys.waitUntil("SMS_ADD")
    end
end)


-- 用户代码已结束---------------------------------------------
-- 结尾总是这一句
sys.run()
-- sys.run()之后后面不要加任何语句!!!!!
