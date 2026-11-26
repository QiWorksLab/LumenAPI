#!/usr/bin/env python3
"""Sequential eight-request gateway benchmark; each successful request may incur quota."""
import csv
import datetime as dt
import json
import os
import pathlib
import statistics
import time
import urllib.error
import urllib.parse
import urllib.request

COUNT = 8
API_KEY = os.environ.get("LUMEN_BENCH_KEY", "").strip()
POST_URL = os.environ.get("LUMEN_BENCH_URL", "https://x.com/xinrui0214/status/2111325730760257624")
BASE_URL = os.environ.get("LUMEN_BENCH_ENDPOINT", "http://127.0.0.1:18080/v1/D_jiexi_V1/")
OUT = pathlib.Path(os.environ.get("LUMEN_BENCH_OUT", "/tmp/lumenapi-bench"))
FIELDS = ["endpoint_ms", "auth_ms", "limits_ms", "billing_key_update_ms", "billing_user_lock_ms", "billing_lots_ms", "billing_balance_update_ms", "billing_ledger_ms", "billing_request_log_ms"]
METRICS = ["wall_ms", "gateway_total_ms", "gateway_other_ms", "upstream_ms", "tls_ms", "handler_total_ms", "billing_log_ms"] + FIELDS
BASELINES = {"previous_fast": {"gateway_total_ms": 186.53}, "previous_slow": {"gateway_total_ms": 370.27}}

def number(value):
    return round(float(value), 3) if isinstance(value, (int, float)) and not isinstance(value, bool) else None

def percentile(values, p):
    ordered = sorted(values)
    if not ordered:
        return None
    index = (len(ordered) - 1) * p
    lo, hi = int(index), min(int(index) + 1, len(ordered) - 1)
    return round(ordered[lo] + (ordered[hi] - ordered[lo]) * (index - lo), 3)

def main():
    if not API_KEY:
        raise SystemExit("Set LUMEN_BENCH_KEY in the environment (do not put it in the script).")
    OUT.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    target = BASE_URL + ("&" if "?" in BASE_URL else "?") + urllib.parse.urlencode({"key": API_KEY, "url": POST_URL})
    rows = []
    for i in range(1, COUNT + 1):
        started = time.perf_counter()
        row = {"run": i, "http_code": None, "success": False, "error": "", "request_id": ""}
        try:
            with urllib.request.urlopen(urllib.request.Request(target, headers={"Accept": "application/json"}), timeout=40) as response:
                row["http_code"] = response.status
                payload = json.loads(response.read())
            row["success"] = response.status == 200 and payload.get("upstream_http_code") == 200 and bool(payload.get("resource_url"))
            row["request_id"] = str(payload.get("request_id", ""))
            timing = payload.get("timing") or {}
            stages = timing.get("gateway_stages") or {}
            for metric in METRICS:
                if metric == "wall_ms":
                    continue
                row[metric] = number(stages.get(metric) if metric in FIELDS else timing.get(metric))
            if not row["success"]:
                row["error"] = str(payload.get("msg") or payload.get("message") or "non-success response")[:200]
        except urllib.error.HTTPError as error:
            row["http_code"] = error.code
            row["error"] = f"HTTP {error.code}"
        except Exception as error:
            row["error"] = f"{type(error).__name__}: {error}"[:200]
        row["wall_ms"] = round((time.perf_counter() - started) * 1000, 3)
        rows.append(row)
        print(f"{i}/{COUNT} HTTP={row['http_code']} success={row['success']} wall={row['wall_ms']}ms gateway={row.get('gateway_total_ms')}ms", flush=True)
    csv_path = OUT / f"gateway_8runs_{stamp}.csv"
    json_path = OUT / f"gateway_8runs_{stamp}.json"
    md_path = OUT / f"gateway_8runs_{stamp}.md"
    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=["run", "http_code", "success", "error", "request_id"] + METRICS)
        writer.writeheader()
        writer.writerows(rows)
    stats = {}
    for metric in METRICS:
        vals = [row[metric] for row in rows if row["success"] and row.get(metric) is not None]
        stats[metric] = {"n": len(vals), "mean": round(statistics.mean(vals), 3) if vals else None, "min": min(vals) if vals else None, "max": max(vals) if vals else None, "p50": percentile(vals, 0.5), "p95": percentile(vals, 0.95)}
    result = {"timestamp": stamp, "count": COUNT, "successful": sum(r["success"] for r in rows), "endpoint": BASE_URL, "post_url": POST_URL, "baselines": BASELINES, "statistics": stats, "runs": rows}
    json_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [f"# LumenAPI 8次连续解析性能对比 ({stamp})", "", f"成功：{result['successful']}/{COUNT}。顺序请求；每次成功解析可能扣除额度。", "", "| 次数 | HTTP | 成功 | 客户端总耗时(ms) | 网关(ms) | 上游(ms) | TLS(ms) | 计费(ms) |", "|---:|---:|:---:|---:|---:|---:|---:|---:|"]
    for row in rows:
        fmt = lambda key: str(row.get(key)) if row.get(key) is not None else "-"
        lines.append(f"| {row['run']} | {fmt('http_code')} | {'是' if row['success'] else '否'} | {fmt('wall_ms')} | {fmt('gateway_total_ms')} | {fmt('upstream_ms')} | {fmt('tls_ms')} | {fmt('billing_log_ms')} |")
    lines += ["", "## 成功请求的统计", "", "| 指标(ms) | 均值 | P50 | P95 | 最小 | 最大 | 样本数 |", "|---|---:|---:|---:|---:|---:|---:|"]
    for metric, stat in stats.items():
        lines.append(f"| {metric} | {stat['mean']} | {stat['p50']} | {stat['p95']} | {stat['min']} | {stat['max']} | {stat['n']} |")
    lines += ["", "## 历史单次样本对比（仅供参考）", "", "历史快样本网关 186.53ms；历史慢样本网关 370.27ms。不能与8次P50直接视为同条件实验。"]
    gateway = stats["gateway_total_ms"]["mean"]
    if gateway is not None:
        lines.append(f"本轮8次成功样本的网关均值 {gateway}ms；相比历史快样本 {round(gateway-186.53,3):+}ms；相比历史慢样本 {round(gateway-370.27,3):+}ms。")
    lines += ["", "注意：wall_ms 包含客户端本地调用开销；gateway_total_ms 是服务器返回的阶段计时。失败请求不纳入性能统计。"]
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"FILES: {csv_path} {json_path} {md_path}", flush=True)

if __name__ == "__main__":
    main()
