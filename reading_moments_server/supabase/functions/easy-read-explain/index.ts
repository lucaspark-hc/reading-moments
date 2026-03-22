import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

Deno.serve(async (req) => {
    try {
        if (req.method === "OPTIONS") {
            return new Response("ok", {
                headers: corsHeaders(),
            });
        }

        const body = await req.json().catch(() => ({}));
        const text = String(body?.text ?? "").trim();

        if (!text) {
            return jsonResponse({ units: [] });
        }

        if (!OPENAI_API_KEY) {
            return jsonResponse(
                {
                    error: "OPENAI_API_KEY is not configured.",
                },
                500,
            );
        }

        const systemPrompt = `
당신은 OCR 문단을 독서 기록용 의미 단위로 나누는 도우미입니다.

사용자가 책 페이지를 OCR로 추출했습니다.
OCR에는 띄어쓰기, 줄바꿈, 일부 오타가 있을 수 있습니다.
문맥을 보면서 자연스럽게 보정하되 과도한 재작성은 하지 마세요.

목표:
- 전체 문단을 의미 단위로 나눈다
- 각 단위는 1~2문장 수준
- 의미가 자연스럽게 끊기는 기준으로 분리
- 문장 일부가 잘리지 않게 한다
- 원문 의미를 유지한다
- 번호/설명/주석 없이 결과만 준다

반드시 JSON 형식으로만 출력:
{
  "units": ["의미 단위 1", "의미 단위 2", "의미 단위 3"]
}
`.trim();

        const openAiRes = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${OPENAI_API_KEY}`,
            },
            body: JSON.stringify({
                model: "gpt-4.1-mini",
                response_format: { type: "json_object" },
                messages: [
                    { role: "system", content: systemPrompt },
                    { role: "user", content: text },
                ],
                temperature: 0.2,
            }),
        });

        const openAiJson = await openAiRes.json();

        if (!openAiRes.ok) {
            return jsonResponse(
                {
                    error: "OpenAI request failed",
                    detail: openAiJson,
                },
                500,
            );
        }

        const content = openAiJson?.choices?.[0]?.message?.content ?? "{}";

        let parsed: { units?: string[] } = {};
        try {
            parsed = JSON.parse(content);
        } catch (_) {
            parsed = { units: [] };
        }

        const units = Array.isArray(parsed.units)
            ? parsed.units
                .map((e) => String(e).trim())
                .filter((e) => e.length > 0)
            : [];

        return jsonResponse({ units });
    } catch (error) {
        return jsonResponse(
            {
                error: String(error),
            },
            500,
        );
    }
});

function corsHeaders() {
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
            "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Content-Type": "application/json; charset=utf-8",
    };
}

function jsonResponse(data: unknown, status = 200) {
    return new Response(JSON.stringify(data), {
        status,
        headers: corsHeaders(),
    });
}