#!/usr/bin/env node
// ============================================================
// 앱성(AppSeong) 스모크 테스트 — 7개 Step 실사용 시나리오
// headless Chromium으로 앱을 열어 전 단계를 클릭 실행하고
// 콘솔 에러·페이지 예외·NaN 표기가 없는지 검사한다.
// 실행: NODE_PATH=<playwright-core가 설치된 node_modules> node appseong/smoke.js
// 환경: PW_CHROMIUM(선택) — chromium 실행 파일 경로 (기본 /opt/pw-browsers/chromium)
// ============================================================
'use strict';
const path = require('path');
const { chromium } = require('playwright-core');

(async () => {
  const errors = [];
  const browser = await chromium.launch({
    executablePath: process.env.PW_CHROMIUM || '/opt/pw-browsers/chromium',
    args: ['--no-sandbox']
  });
  const page = await browser.newPage();
  page.on('console', msg => { if (msg.type() === 'error') errors.push(`console: ${msg.text()}`); });
  page.on('pageerror', err => errors.push(`pageerror: ${err.message}`));

  const url = 'file://' + path.resolve(__dirname, '..', 'BIM_Slope_EL_Automation.html');
  await page.goto(url);

  const results = [];
  const check = async (label) => {
    const txt = await page.locator('#stepPanel').innerText().catch(() => '');
    const bad = /\bNaN\b|\bundefined\b|\bnull%/.test(txt);
    results.push({ label, ok: !bad && errors.length === 0, detail: bad ? 'NaN/undefined 표기 발견' : (errors[errors.length - 1] || '') });
    if (bad) errors.length = 0;
  };
  const step = async (n) => { await page.locator('.step-btn').nth(n - 1).click(); };
  const clickCanvas = async (x, y) => { await page.locator('#surfCanvas').click({ position: { x, y } }); };

  await page.locator('#btnLoadSurface').click();

  // Step 1: 표고점 추출
  await step(1); await clickCanvas(150, 150); await clickCanvas(300, 200);
  await page.locator('button', { hasText: 'Extract Elevation' }).click();
  await check('Step 1 표고점 추출');

  // Step 2: 경사도 산출
  await step(2); await clickCanvas(100, 300); await clickCanvas(400, 120);
  await page.locator('button', { hasText: 'Calculate Slope' }).click();
  await check('Step 2 경사도 산출');

  // Step 3: 워터 드롭
  await step(3); await clickCanvas(250, 180);
  await page.locator('button', { hasText: 'Trace Water Drop' }).click();
  await check('Step 3 워터 드롭');

  // Step 4: 표면 분석
  await step(4);
  await page.locator('button', { hasText: 'Run Surface Analysis' }).click();
  await check('Step 4 표면 분석');

  // Step 5: 유역면적
  await step(5); await clickCanvas(280, 250);
  await page.locator('button', { hasText: 'Delineate Catchment' }).click();
  await check('Step 5 유역면적');

  // Step 6: 법규 검토 (전 유형 × 전 국가 조합 일부)
  await step(6);
  for (const [type, ctry] of [['road', 'korea'], ['walkway', 'korea'], ['barrier_free', 'all'], ['general', 'all']]) {
    await page.locator('#typeInput').selectOption(type);
    await page.locator('#countryInput').selectOption(ctry);
    await page.locator('button', { hasText: 'Check Compliance' }).click();
    await check(`Step 6 법규 검토 (${type}/${ctry})`);
  }

  // Step 7: 스크립트 생성 (4개 플랫폼 전환)
  await step(7);
  for (let i = 0; i < 4; i++) {
    await page.locator('.platform-card').nth(i).click();
    await check(`Step 7 스크립트 생성 (platform ${i + 1})`);
  }

  await browser.close();

  console.log('=== 앱성 스모크 테스트 ===');
  let failed = 0;
  for (const r of results) {
    console.log(`  ${r.ok ? 'PASS' : 'FAIL'}  ${r.label}${r.ok ? '' : ' — ' + r.detail}`);
    if (!r.ok) failed++;
  }
  console.log(`=== 결과: ${results.length - failed} PASS / ${failed} FAIL ===`);
  process.exit(failed ? 1 : 0);
})().catch(e => { console.error('스모크 테스트 실행 실패:', e.message); process.exit(1); });
