-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "sms_forwarding"
VERSION = "1.0.0"

log.info("main", PROJECT, VERSION)

local pushURL = "https://sms.kwen.page/api"

--缓存消息
local buff = {}

-- 引入必要的库文件(lua编写), 内部库不需要require
sys = require("sys")
require "sysplus" -- http库需要这个sysplus

wdt.init(9000)--初始化watchdog设置为9s
sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗

-- SIM 自动恢复, 周期性获取小区信息, 网络遇到严重故障时尝试自动恢复等功能
mobile.setAuto(10000, 30000, 8, true, 60000)

--运营商给的dns经常抽风，手动指定
socket.setDNS(nil, 1, "119.29.29.29")
socket.setDNS(nil, 2, "114.114.114.114")

--订阅短信消息
sys.subscribe("SMS_INC",function(phone,data)
    --来新消息了
    log.info("notify","got sms",phone,data)
    table.insert(buff,{phone,data})
    sys.publish("SMS_ADD")--推个事件
end)

sys.taskInit(function()
    sys.waitUntil("IP_READY", 1000 * 60 * 5)
    while true do
        log.info("notify", "wait for a new sms")
        sys.waitUntil("SMS_ADD")
        print("zzz",collectgarbage("count"))
        while #buff > 0 do--把消息读完
            local sms = table.remove(buff,1)
            local data = sms[2]

            local msg = {
                from = sms[1],
                text = data
            }
            local req_body = json.encode(msg)

            log.info("notify", "push to server", req_body)

            local code, h, resp_body
            for i=1,5 do
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
        end
        print("zzz",collectgarbage("count"))
    end
end)


-- 用户代码已结束---------------------------------------------
-- 结尾总是这一句
sys.run()
-- sys.run()之后后面不要加任何语句!!!!!
