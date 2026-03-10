console.log("✅ index.js loaded at", new Date().toISOString());

require("dotenv").config();
const express = require("express");
const axios = require("axios");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");

const app = express();
app.use(cors());
app.use(express.json());

// ====== Config ======
const API_KEY = process.env.GEMINI_API_KEY;
const PORT = Number(process.env.PORT || 3000);

const RAW_MODEL = (process.env.GEMINI_MODEL || "gemini-2.5-flash").trim();
const MODEL_NAME = RAW_MODEL.startsWith("models/")
  ? RAW_MODEL
  : `models/${RAW_MODEL}`;
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/${MODEL_NAME}:generateContent`;

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!API_KEY) {
  console.error("❌ GEMINI_API_KEY가 설정되어 있지 않습니다(.env 확인).");
}
if (!SUPABASE_URL) {
  console.error("❌ SUPABASE_URL이 설정되어 있지 않습니다(.env 확인).");
}
if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("❌ SUPABASE_SERVICE_ROLE_KEY가 설정되어 있지 않습니다(.env 확인).");
}

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ====== Helpers ======
function buildBookDescriptionPrompt(title, author, publisher, publishedDate) {
  return `
다음 책의 소개글 초안을 한국어로 3~5문장 정도로 작성해줘.

[책 정보]
제목: ${title || ""}
저자: ${author || ""}
출판사: ${publisher || ""}
출간일: ${publishedDate || ""}

조건:
- 독서모임 앱에 들어갈 책 소개 문구
- 너무 과장하지 말 것
- 자연스럽고 간결한 한국어
- 스포일러는 피할 것

출력은 일반 텍스트만 작성해줘.
`.trim();
}

function buildPrompt(bookTitle, author) {
  return `
"${bookTitle}" (${author || "저자 미상"}) 도서에 대한 독서 모임 토론 질문 3개를 만들어줘.

조건:
- 질문은 한 문장
- 짧고 간결하게
- 핵심 토론 질문
- 불필요한 설명 금지

출력은 반드시 아래 JSON 형식만:
{"questions":["질문1","질문2","질문3"]}
`.trim();
}

function buildReasonPrompt(title, author, description) {
  return `
다음 책으로 독서모임을 만든다고 가정하고,
호스트가 사용할 "책 선정 이유" 초안을 한국어로 3~5문장 정도로 작성해줘.

[책 정보]
제목: ${title || ""}
저자: ${author || ""}
소개: ${description || ""}

조건:
- 너무 길지 않게
- 자연스러운 한국어
- 홍보문구처럼 과장하지 말 것
- 독서모임에서 왜 이야기할 가치가 있는지 중심으로 작성

출력은 일반 텍스트만 작성해줘.
`.trim();
}

function cleanMaybeCodeBlock(text = "") {
  return String(text).replace(/```json|```/g, "").trim();
}

function normalizeGoogleBook(item) {
  const info = item?.volumeInfo || {};
  const identifiers = Array.isArray(info.industryIdentifiers)
    ? info.industryIdentifiers
    : [];

  const isbn13 =
    identifiers.find((x) => x.type === "ISBN_13")?.identifier ||
    identifiers.find((x) => x.type === "ISBN_10")?.identifier ||
    "";

  return {
    googleBookId: item?.id || "",
    title: info.title || "",
    author: Array.isArray(info.authors) ? info.authors.join(", ") : "",
    isbn: isbn13,
    coverUrl: info.imageLinks?.thumbnail || info.imageLinks?.smallThumbnail || "",
    description: info.description || "",
    publisher: info.publisher || "",
    publishedDate: info.publishedDate || "",
  };
}

async function generatePlainTextFromGemini(prompt) {
  const response = await axios.post(
    GEMINI_URL,
    {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
      },
    },
    {
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": API_KEY,
      },
      timeout: 30000,
    }
  );

  const candidate = response.data?.candidates?.[0];
  if (!candidate) {
    throw new Error(
      `No candidates. details=${JSON.stringify(response.data).slice(0, 500)}`
    );
  }

  const text = candidate?.content?.parts?.[0]?.text ?? "";
  return String(text).trim();
}

async function generateQuestionsFromGemini({ bookTitle, author }) {
  const prompt = buildPrompt(bookTitle, author);

  const response = await axios.post(
    GEMINI_URL,
    {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.7,
      },
    },
    {
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": API_KEY,
      },
      timeout: 20000,
    }
  );

  const candidate = response.data?.candidates?.[0];
  if (!candidate) {
    throw new Error(
      `No candidates. details=${JSON.stringify(response.data).slice(0, 500)}`
    );
  }

  const rawText = candidate?.content?.parts?.[0]?.text ?? "";
  const cleaned = cleanMaybeCodeBlock(rawText);

  const parsed = JSON.parse(cleaned);
  if (!parsed || !Array.isArray(parsed.questions)) {
    throw new Error(`Invalid schema. cleaned=${cleaned.slice(0, 300)}`);
  }

  return parsed.questions
    .slice(0, 3)
    .map((q) => String(q).trim())
    .filter(Boolean);
}

async function loadMeetingBundle(meetingId) {
  const { data: meeting, error: meetingError } = await supabaseAdmin
    .from("meetings")
    .select(`
      id,
      title,
      host_id,
      meeting_date,
      location,
      books (
        id,
        title,
        author
      )
    `)
    .eq("id", meetingId)
    .single();

  if (meetingError) throw meetingError;

  const { data: questions, error: qError } = await supabaseAdmin
    .from("questions")
    .select("id, question, created_at")
    .eq("meeting_id", meetingId)
    .order("created_at", { ascending: true });

  if (qError) throw qError;

  const { data: answers, error: aError } = await supabaseAdmin
    .from("answers")
    .select(`
      id,
      question_id,
      answer,
      created_at,
      user_id,
      users (
        nickname
      )
    `)
    .eq("meeting_id", meetingId)
    .order("created_at", { ascending: true });

  if (aError) throw aError;

  return {
    meeting,
    questions: questions || [],
    answers: answers || [],
  };
}

function buildRecapPrompt(bundle) {
  const meeting = bundle.meeting;
  const book = meeting.books || {};

  const questionLines = bundle.questions
    .map((q, idx) => {
      const answerLines = bundle.answers
        .filter((a) => a.question_id === q.id)
        .map((a) => `- ${(a.users?.nickname || a.user_id)}: ${a.answer}`)
        .join("\n");

      return `질문 ${idx + 1}: ${q.question}\n답변들:\n${answerLines || "- 답변 없음"}`;
    })
    .join("\n\n");

  return `
다음 독서모임 내용을 읽고 한국어로 보기 좋게 요약해줘.

[모임 정보]
모임 제목: ${meeting.title}
책 제목: ${book.title || ""}
저자: ${book.author || ""}
일시: ${meeting.meeting_date}
장소: ${meeting.location || "-"}

[질문과 답변]
${questionLines}

요구사항:
1. 전체 흐름 요약
2. 핵심 토론 포인트 3~5개
3. 인상적인 답변/관점 정리
4. 마지막에 "한 줄 총평" 추가

출력은 자연스러운 한국어 텍스트로만 작성해줘.
`.trim();
}

async function assertHost({ meetingId, hostUserId }) {
  const { data, error } = await supabaseAdmin
    .from("meetings")
    .select("id, host_id")
    .eq("id", meetingId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new Error("meeting not found");
  if (!data.host_id) throw new Error("meeting has no host_id");
  if (data.host_id !== hostUserId) throw new Error("not host");

  return true;
}

async function insertQuestions({ meetingId, hostUserId, questions }) {
  const rows = questions.map((q) => ({
    meeting_id: meetingId,
    created_by: hostUserId,
    question: q,
  }));

  const { data, error } = await supabaseAdmin
    .from("questions")
    .insert(rows)
    .select("id, question");

  if (error) throw error;
  return data;
}

// ====== Routes ======
app.post("/books/generate-description", async (req, res) => {
  const { title, author, publisher, publishedDate } = req.body || {};

  if (!title) {
    return res.status(400).json({ error: "title은 필수입니다." });
  }

  if (!API_KEY) {
    return res.status(500).json({ error: "GEMINI_API_KEY가 설정되어 있지 않습니다." });
  }

  try {
    const prompt = buildBookDescriptionPrompt(title, author, publisher, publishedDate);
    const description = await generatePlainTextFromGemini(prompt);

    return res.json({
      ok: true,
      description,
    });
  } catch (e) {
    const msg = e?.message || String(e);
    console.error("❌ generate-description error:", msg);
    return res.status(500).json({
      error: "generate-description failed",
      details: msg,
    });
  }
});

app.post("/books/generate-reason", async (req, res) => {
  const { title, author, description } = req.body || {};

  if (!title) {
    return res.status(400).json({ error: "title은 필수입니다." });
  }

  if (!API_KEY) {
    return res.status(500).json({ error: "GEMINI_API_KEY가 설정되어 있지 않습니다." });
  }

  try {
    const prompt = buildReasonPrompt(title, author, description);
    const reason = await generatePlainTextFromGemini(prompt);
    return res.json({ ok: true, reason });
  } catch (e) {
    const msg = e?.message || String(e);
    console.error("❌ generate-reason error:", msg);
    return res.status(500).json({
      error: "generate-reason failed",
      details: msg,
    });
  }
});

app.post("/generate-questions", async (req, res) => {
  const { meetingId, bookTitle, author, hostUserId } = req.body || {};

  if (!meetingId || !bookTitle || !hostUserId) {
    return res.status(400).json({
      error: "meetingId, bookTitle, hostUserId는 필수입니다.",
    });
  }

  if (!API_KEY) {
    return res.status(500).json({ error: "GEMINI_API_KEY가 설정되어 있지 않습니다." });
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return res.status(500).json({
      error: "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 설정이 필요합니다.",
    });
  }

  try {
    await assertHost({ meetingId, hostUserId });

    const aiQuestions = await generateQuestionsFromGemini({ bookTitle, author });

    const questions = [
      "이 작품을 읽고 전반적인 느낌(총평) 한마디를 써주세요. (50자 내)",
      ...aiQuestions,
    ];

    const inserted = await insertQuestions({ meetingId, hostUserId, questions });

    return res.json({
      ok: true,
      questions,
      inserted,
    });
  } catch (e) {
    const msg = e?.message || String(e);
    console.error("❌ generate-questions error:", msg);
    return res.status(500).json({
      error: "generate-questions failed",
      details: msg,
    });
  }
});

app.get("/meetings/:meetingId/questions", async (req, res) => {
  const meetingId = Number(req.params.meetingId);
  if (!meetingId) {
    return res.status(400).json({ error: "invalid meetingId" });
  }

  try {
    const { data, error } = await supabaseAdmin
      .from("questions")
      .select("id, meeting_id, created_by, question, created_at")
      .eq("meeting_id", meetingId)
      .order("created_at", { ascending: true});

    if (error) throw error;

    return res.json({
      ok: true,
      questions: data || [],
    });
  } catch (e) {
    const msg = e?.message || String(e);
    return res.status(500).json({
      error: "load questions failed",
      details: msg,
    });
  }
});

app.post("/meetings/:meetingId/generate-recap", async (req, res) => {
  const meetingId = Number(req.params.meetingId);
  const { hostUserId } = req.body || {};

  if (!meetingId || !hostUserId) {
    return res.status(400).json({ error: "meetingId, hostUserId는 필수입니다." });
  }

  try {
    await assertHost({ meetingId, hostUserId });

    const bundle = await loadMeetingBundle(meetingId);
    const prompt = buildRecapPrompt(bundle);
    const recapText = await generatePlainTextFromGemini(prompt);

    const { data, error } = await supabaseAdmin
      .from("meeting_recaps")
      .insert({
        meeting_id: meetingId,
        created_by: hostUserId,
        content: recapText,
        is_public: false,
      })
      .select("id, meeting_id, created_by, content, is_public, created_at")
      .single();

    if (error) throw error;

    return res.json({
      ok: true,
      recap: data,
    });
  } catch (e) {
    const msg = e?.message || String(e);
    console.error("❌ generate-recap error:", msg);
    return res.status(500).json({
      error: "generate-recap failed",
      details: msg,
    });
  }
});

app.get("/meetings/:meetingId/recaps", async (req, res) => {
  const meetingId = Number(req.params.meetingId);
  if (!meetingId) {
    return res.status(400).json({ error: "invalid meetingId" });
  }

  try {
    const { data, error } = await supabaseAdmin
      .from("meeting_recaps")
      .select("id, meeting_id, created_by, content, is_public, created_at")
      .eq("meeting_id", meetingId)
      .order("created_at", { ascending: false });

    if (error) throw error;

    return res.json({
      ok: true,
      recaps: data || [],
    });
  } catch (e) {
    const msg = e?.message || String(e);
    return res.status(500).json({
      error: "load recaps failed",
      details: msg,
    });
  }
});

app.get("/books/search", async (req, res) => {
  const q = String(req.query.q || "").trim();
  if (!q) {
    return res.status(400).json({ error: "q는 필수입니다." });
  }

  try {
    const { data: localBooks, error: localError } = await supabaseAdmin
      .from("books")
      .select("id, isbn, title, author, cover_url, description")
      .ilike("title", `%${q}%`)
      .limit(10);

    if (localError) throw localError;

    const normalizedLocalBooks = (localBooks || []).map((b) => ({
      googleBookId: `local-${b.id}`,
      title: b.title || "",
      author: b.author || "",
      isbn: b.isbn || "",
      coverUrl: b.cover_url || "",
      description: b.description || "",
      publisher: "",
      publishedDate: "",
      source: "local",
    }));

    if (normalizedLocalBooks.length >= 5) {
      return res.json({
        ok: true,
        source: "local",
        books: normalizedLocalBooks,
      });
    }

    try {
      const response = await axios.get("https://www.googleapis.com/books/v1/volumes", {
        params: {
          q,
          langRestrict: "ko",
          maxResults: 10,
        },
        timeout: 15000,
      });

      const items = Array.isArray(response.data?.items) ? response.data.items : [];
      const googleBooks = items
        .map(normalizeGoogleBook)
        .filter((b) => b.title)
        .map((b) => ({
          ...b,
          source: "google",
        }));

      const merged = [...normalizedLocalBooks];
      for (const g of googleBooks) {
        const exists = merged.some(
          (x) =>
            (x.isbn && g.isbn && x.isbn === g.isbn) ||
            (x.title && g.title && x.title === g.title)
        );
        if (!exists) {
          merged.push(g);
        }
      }

      return res.json({
        ok: true,
        source: "mixed",
        books: merged,
      });
    } catch (googleError) {
      const status = googleError.response?.status;

      if (status === 429) {
        console.warn("⚠️ Google Books quota exceeded. local fallback only.");
        return res.json({
          ok: true,
          source: "local-fallback",
          books: normalizedLocalBooks,
          warning: "Google Books quota exceeded",
        });
      }

      throw googleError;
    }
  } catch (e) {
    const msg = e.response?.data || e.message;
    console.error("❌ books/search error:", msg);
    return res.status(500).json({
      error: "book search failed",
      details: msg,
    });
  }
});

app.get("/health", (req, res) => {
  res.json({ ok: true });
});

app.listen(PORT, () => {
  console.log(`🚀 서버 시작: http://localhost:${PORT}`);
});