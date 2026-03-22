// Supabase Edge Function
// function name: easy-read-explain

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

Deno.serve(async (req) => {
    try {
        if (req.method === "OPTIONS") {
            return new Response("ok", {
                headers: corsHeaders(),
            });
        }

        if (!OPENAI_API_KEY) {
            return jsonResponse(
                {
                    error: "OPENAI_API_KEY is not configured.",
                },
                500,
            );
        }

        const body = await req.json().catch(() => ({}));
        const text = String(body?.text ?? "").trim();
        const prompt = String(body?.prompt ?? "").trim();

        if (text.isEmpty ?? false) {
            return jsonResponse(
                {
                    error: "text is required.",
                },
                400,
            );
        }

        const systemPrompt = prompt.isNotEmpty
            ? prompt
            : `
당신은 독서를 돕는 설명 도우미입니다.

사용자가 읽다가 이해하기 어려운 문장을 보냈습니다.
이 문장을 쉽고 짧게 풀어주세요.

문장에는 OCR로 인해 일부 오타가 있을 수 있습니다.
문맥을 기준으로 자연스럽게 해석해주세요.

조건:
- 최대 3~4문장으로 설명
- 첫 문장은 반드시 "쉽게 말하면,"으로 시작
- 어려운 단어는 쉬운 말로 바꿔 설명
- 핵심 의미만 전달
- 단정적인 해석은 피하고 "~로 이해할 수 있습니다" 형태 사용
- 작가 의도 추측 금지
- 배경 설명 금지
- 장황한 설명 금지

출력은 반드시 JSON 형식:
{
  "summary": "한 줄 요약",
  "explanation": "간단한 의미 설명"
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
                    {
                        role: "system",
                        content: systemPrompt,
                    },
                    {
                        role: "user",
                        content: `문장:\n"${text}"`,
                    },
                ],
                temperature: 0.4,
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

        let parsed: { summary?: string; explanation?: string } = {};
        try {
            parsed = JSON.parse(content);
        } catch (_) {
            parsed = {
                summary: content,
                explanation: content,
            };
        }

        let summary = String(parsed.summary ?? "").trim();
        let explanation = String(parsed.explanation ?? "").trim();

        if (!summary && explanation) {
            summary = explanation;
        }
        if (!explanation && summary) {
            explanation = summary;
        }

        if (!summary.startsWith("쉽게 말하면,")) {
            summary = `쉽게 말하면, ${summary.replace(/^쉽게 말하면[, ]*/u, "")}`.trim();
        }

        return jsonResponse({
            summary,
            explanation,
        });
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