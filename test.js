#!/bin/env -S qjs -m
import * as http from "./http-server.js";
import * as os from "os";
import * as std from "std";
import * as path from "path.so";
import Console from "console.js";
console.log("path", Object.keys(path));

const mainProcName = (scriptArgs[0].match(/.*\/(.*)/) ?? [])[1] || scriptArgs[0];

const inspectOptions = {
    maxStringLength: 100,
    compact: 1
};

globalThis.console = new Console(inspectOptions);

for(let [fd,st] of [0,1,2].map(fd => [fd,http.fstat(fd)])) {
    console.log(`${fd}:`, st);
}

try {
    http.setProcName(mainProcName);
    http.start({
        listen: "0.0.0.0",
        port: 7000,
        minWorkers: 1,
        maxWorkers: 20,
        workerTimeoutSec: 300,
        requestHandler: handleRequest
    });
} catch (e) {
    console.log(e);
    console.log(e?.stack || "");
    http.shutdown(); //shutdown workers
}

function handleRequest(req) {
    const { h, url, method, httpMajor, httpMinor, query, originalActionPath, actionPath, remoteAddr, p } = req;
    let rsp = { status: 404, h: { "Content-Type": "text/html; charset=UTF-8" }, body: `<html><head></head><body>The URL ${req.path} was not found on this server</body>` };

    //    if (/\/favicon.ico$/.test(req.path)) return;

    console.log("request", req);

    let file = req.path.replace(/^\//, "");
    console.log("file", file);

    if (file === "") {
        rsp = {
            status: 302,
            h: {
                Host: "localhost",
                "User-Agent": "quickjs-http",
                Location: "/index.html"
            }
        };
    } else {
        file = path.collapse(file);
        console.log("file", file);
        const type =
            ({
                js: "application/javascript",
                mjs: "application/javascript",
                c: "text/x-csrc",
                h: "text/x-chdr",
                diff: "text/x-diff",
                html: "text/html",
                txt: "text/plain"
            }[file.replace(/.*\./g, "")] ?? "text/plain") + "; charset=utf-8";

        let [obj, err] = os.stat(file);

        console.log("stat:", obj);

        if (!err) {
            rsp = {
                status: 200,
                h: {
                    Host: "localhost",
                    "User-Agent": "quickjs-http",
                    "Content-Type": type,
                    "Cache-Control": "no-cache",
                    Date: new Date(obj.mtime).toUTCString()
                },
                body: std.loadFile(file, "utf-8")
            };
        }
    }
    console.log("rsp", rsp);
    return rsp;
}

function simpleFetchUrl(host, port, req) {
    var conn = http.connect(host, port);
    http.sendHttpRequest(conn, req);
    var resp = http.recvHttpResponse(conn, req.maxBodySize || -1);
    http.close(conn);
    return resp;
}

function simpleSendMail(host, port, from, to, subj, text) {
    var conn = http.connect("10.8.1.1", 587);
    assertResp("220 ");
    assertResp("250 ", `ehlo localhost\n`);
    assertResp("250 ", `mail from: ${from}\n`);
    assertResp("250 ", `rcpt to: ${to}\n`);
    assertResp("354 ", "data\n");
    assertResp("250 ", `Subject: ${subj}\nFrom: ${from}\nTo: ${to}\nContent-Type: text/plain; charset=utf-8;\n\n${text}\req\n.\req\n`);
    http.sendString(conn, "quit\n");
    http.close(conn);

    function assertResp(respStart, cmd) {
        if (cmd) http.sendString(conn, cmd);
        let resp = http.recvLine(conn);
        if (resp.indexOf(respStart) != 0) {
            while (1) {
                //could receive multiple lines in rsp to ehlo
                if (resp.match(/^\d\d\d /gm)) break;
                resp += http.recvLine(conn);
            }
            if (!resp.match(new RegExp(`^${respStart}`, "mg"))) throw new Error(`Unexpected reply: ${resp} in rsp to: ${cmd}`);
        }
    }
}
