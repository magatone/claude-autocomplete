![english-autocomplete](assets/banner.png)

# english-autocomplete

[English](README.md) | **한국어**

Claude Code 입력창에서 영어 단어를 칠 때, 스마트폰 키보드처럼 단어를 추천해 주는
플러그인입니다. 영어 단어를 두 글자 이상 입력하면 입력창 위에 많이 쓰는 순서대로
후보가 최대 5개 나타납니다. 처음 입력한 대소문자는 그대로 유지됩니다
(`Recom` -> `Recommend`).

Claude Code 2.1.292 이상이 필요합니다 (`prompt.autocomplete` 플러그인 이벤트 사용).

## 설치

Claude Code 터미널 세션에서 다음을 입력합니다.

```
/plugin install english-autocomplete --marketplace magatone/claude-autocomplete
```

마켓플레이스를 추가할지 물으면 `y`를 누르고, 설치 범위를 고릅니다 (기본값은 user 범위).

## 사용 방법

1. 입력창에 영어 단어를 두 글자 이상 입력합니다 (예: `recom`).
2. 입력창 위에 많이 쓰는 순서대로 추천 단어가 최대 5개 나타납니다.
3. 위/아래 화살표 키로 원하는 단어를 고릅니다.
4. `Tab`을 누르면 입력하던 글자가 고른 단어로 바뀝니다.

## 개발

```
claude --plugin-dir ./claude-autocomplete
claude plugin test ./claude-autocomplete
```

## 앞으로의 계획

Codex 버전도 곧 출시할 예정입니다.

## 다른 언어

이 문서는 영어와 한국어로 제공됩니다. 다른 언어는 수요가 확인되면 추가할 예정입니다.

## 라이선스

- 코드: MIT, `LICENSE` 참고.
- 단어 목록 (`data/wordfreq-en-25000-log.json`):
  [aparrish/wordfreq-en-25000](https://github.com/aparrish/wordfreq-en-25000)에서 가져왔으며,
  Robyn Speer의 [wordfreq](https://github.com/rspeer/wordfreq)에서 추출한 목록입니다.
  wordfreq 데이터는 [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) 라이선스이며,
  이 단어 목록도 같은 라이선스로 재배포합니다.
  부적절한 단어는 걸러져 있지 않습니다.
