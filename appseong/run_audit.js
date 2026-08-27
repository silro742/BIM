#!/usr/bin/env node
// ============================================================
// 앱성(AppSeong) 감사 오케스트레이터 — 수치 회귀 검증
// BIM_Slope_EL_Automation.html의 계산 엔진을 해석해(analytic solution)와
// 대조하고, 감사보고서의 결함 ID(H-*, B-*)가 재발하지 않는지 검사한다.
// 실행: node appseong/run_audit.js
// ============================================================
'use strict';
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const HTML_PATH = path.join(__dirname, '..', 'BIM_Slope_EL_Automation.html');
const html = fs.readFileSync(HTML_PATH, 'utf-8');

// ---- ① 수집기: HTML에서 스크립트 본문 추출, DOM 스텁으로 평가 ----
const m = html.match(/<script>([\s\S]*)<\/script>/);
if (!m) { console.error('script 블록을 찾지 못함'); process.exit(1); }

function domStub() {
  const el = () => ({ innerHTML: '', style: {}, value: '', width: 560, height: 420 });
  return { getElementById: () => el(), createElement: el };
}
const sandbox = new Function('document', 'window', m[1] + `
;return {delaunayTriangulate, TINSurface, checkCompliance, REGULATIONS, SCRIPT_TEMPLATES, generateSampleSurface, escapeHTML};`);
const api = sandbox(domStub(), {});
const { TINSurface, checkCompliance, REGULATIONS, SCRIPT_TEMPLATES } = api;

// ---- 테스트 지형 ----
function grid(fn, n = 11, spacing = 10) {
  const pts = [];
  for (let i = 0; i < n; i++) for (let j = 0; j < n; j++)
    pts.push({ x: i * spacing, y: j * spacing, z: fn(i * spacing, j * spacing) });
  return pts;
}
const flat = new TINSurface(grid(() => 100));           // 평면 z=100
const incline = new TINSurface(grid((x) => 0.1 * x));   // 단일경사면 z=0.1x (10%)

let passed = 0, failed = 0;
function test(id, name, fn) {
  try { fn(); passed++; console.log(`  PASS  [${id}] ${name}`); }
  catch (e) { failed++; console.log(`  FAIL  [${id}] ${name}\n        ${e.message}`); }
}
const near = (a, b, tol, msg) => assert.ok(Math.abs(a - b) <= tol, `${msg}: got ${a}, want ${b}±${tol}`);

console.log('=== 앱성 수치 회귀 검증 ===\n');

// ---- ④ 결함 탐지기: 해석해 대조 ----
test('NUM-01', '평면 지형: 임의 지점 표고 = 100', () => {
  near(flat.getElevation(37.3, 51.8), 100, 1e-6, '표고');
});
test('NUM-02', '평면 지형: 경사도 0%', () => {
  const r = flat.calculateSlope(5, 5, 80, 60);
  near(r.slope_percentage, 0, 1e-6, '경사%');
  near(r.slope_degrees, 0, 1e-6, '경사각');
});
test('NUM-03', '경사면(10%): 표고 보간 정확도', () => {
  near(incline.getElevation(43.7, 22.1), 4.37, 0.01, '표고');
});
test('NUM-04', '경사면(10%): 경사도% = 10, 각도 = atan(0.1)', () => {
  const r = incline.calculateSlope(0, 50, 80, 50);
  near(r.slope_percentage, 10, 0.05, '경사%');
  near(r.slope_degrees, Math.atan(0.1) * 180 / Math.PI, 0.05, '경사각');
  assert.ok(r.slope_ratio.startsWith('1:10'), `경사비: ${r.slope_ratio}`);
});
test('B-05', '3D 모드에서도 경사도%·각도는 수평거리 기준으로 불변', () => {
  const r2d = incline.calculateSlope(0, 50, 80, 50, false);
  const r3d = incline.calculateSlope(0, 50, 80, 50, true);
  near(r3d.slope_percentage, r2d.slope_percentage, 1e-9, '경사% 불변');
  near(r3d.slope_degrees, r2d.slope_degrees, 1e-9, '경사각 불변');
});
test('B-04', '방향 화살표 각도 = 실제 내리막 평면 방위각', () => {
  // A(80,50,8) → B(0,50,0): 내리막, 내리막 방향 = -X = 180°
  // 앱은 각도를 소수 3자리(rad)로 반올림해 반환하므로 허용오차 5e-4
  const r = incline.calculateSlope(80, 50, 0, 50);
  near(Math.abs(r.direction_arrow_angle), Math.PI, 5e-4, '내리막 방위각(-X)');
  // A(0,50,0) → B(80,50,8): 오르막, 내리막 방향은 여전히 -X = 180°
  const r2 = incline.calculateSlope(0, 50, 80, 50);
  near(Math.abs(r2.direction_arrow_angle), Math.PI, 5e-4, '오르막 입력 시에도 내리막 방위각');
});
test('NUM-05', '워터드롭: 경사면에서 -X 방향으로 하강, 낙차 > 0', () => {
  const wp = incline.traceWaterDrop(90, 50, 500, 2.0);
  assert.ok(wp && wp.path.length > 5, '경로 생성');
  const first = wp.path[0], last = wp.path[wp.path.length - 1];
  assert.ok(last.x < first.x, `-X 방향 하강: ${first.x} → ${last.x}`);
  assert.ok(wp.elevation_drop > 0, `낙차: ${wp.elevation_drop}`);
});
test('B-02', '유역면적: 경사면에서 흐름 방향 반영 (전체 면적 과대산출 금지)', () => {
  const total = incline.analyzeSurface().statistics.total_area;
  const c = incline.delineateCatchment(15, 50);
  assert.ok(c && c.area > 0, '유역 생성');
  assert.ok(c.area < total * 0.45, `유역 ${c.area} < 전체 ${total}의 45% (흐름 방향 미검사 시 상류 전체 편입)`);
  assert.ok('contributing_vertices' in c && !('boundary_points' in c), 'B-03: 필드명 정정 확인');
});
test('B-01', '경사 화살표 색상 = 해당 경사밴드 색상 (minSlope 오프셋 반영)', () => {
  const a = new TINSurface(grid((x, y) => 0.1 * x + 0.03 * y + 2 * Math.sin(x / 17))).analyzeSurface();
  const bands = a.slope_bands;
  for (const ar of a.slope_arrows) {
    const band = bands.find((b, i) => ar.slope_degrees >= b.min_slope - 1e-6 &&
      (ar.slope_degrees < b.max_slope + 1e-6 || i === bands.length - 1));
    assert.ok(band, `밴드 미발견: ${ar.slope_degrees}°`);
    assert.strictEqual(ar.color, band.color, `화살표색 ${ar.color} ≠ 밴드색 ${band.color} (경사 ${ar.slope_degrees}°)`);
  }
});
test('B-06', '밴드 삼각형 수 합계 = 전체 삼각형 수 (경계값 누락 금지)', () => {
  const a = incline.analyzeSurface();
  const elevSum = a.elevation_bands.reduce((s, b) => s + b.triangle_count, 0);
  const slopeSum = a.slope_bands.reduce((s, b) => s + b.triangle_count, 0);
  assert.strictEqual(elevSum, a.statistics.total_triangles, `표고밴드 합 ${elevSum}`);
  assert.strictEqual(slopeSum, a.statistics.total_triangles, `경사밴드 합 ${slopeSum}`);
});
test('NUM-06', '델로니: n×n 격자의 삼각형 수 = 2(n-1)²', () => {
  assert.strictEqual(flat.triangles.length, 2 * 10 * 10, `삼각형 수 ${flat.triangles.length}`);
});
test('NUM-07', '면적: 평면 100×100 = 10000, 경사면 = 10000×sec(atan 0.1)', () => {
  near(flat.analyzeSurface().statistics.total_area, 10000, 1, '평면 면적');
  near(incline.analyzeSurface().statistics.total_area, 10000 * Math.sqrt(1.01), 1, '경사면 면적');
});

// ---- ③ 검증기: 법규·주장 검사 ----
test('H-05', '무조건-통과 검사는 informational로 명시되어야 함', () => {
  const r = checkCompliance(0.1, 'general', 'all');
  for (const ck of r.checks) {
    if (ck.rule.includes('NBIMS') || ck.rule.includes('ISO 19650'))
      assert.ok(ck.informational === true, `정보성 미표기: ${ck.rule}`);
  }
  assert.strictEqual(r.is_compliant, false, '실패 검사가 있으면 NON-COMPLIANT');
});
test('H-03', '배리어프리 기준의 출처는 배수기준이 아닌 KR-BF-001', () => {
  const r = checkCompliance(10, 'barrier_free', 'korea');
  const bf = r.checks.find(c => c.rule.includes('Barrier-free'));
  assert.ok(bf && bf.standard === 'KR-BF-001', `출처: ${bf && bf.standard}`);
  assert.strictEqual(r.is_compliant, false, '10% 경사로는 부적합');
  assert.ok(checkCompliance(8, 'barrier_free', 'korea').is_compliant, '8%는 적합');
});
test('H-10', 'walkway 유형 검사 존재 (데이터-로직 일치)', () => {
  assert.strictEqual(checkCompliance(9, 'walkway', 'korea').is_compliant, false, '9% 보행로 부적합');
  assert.strictEqual(checkCompliance(5, 'walkway', 'korea').is_compliant, true, '5% 보행로 적합');
});
test('CHK-01', '기본 판정 정합성: 도로 2% 적합, 0.5% 부적합', () => {
  assert.ok(checkCompliance(2, 'road', 'korea').is_compliant);
  assert.ok(!checkCompliance(0.5, 'road', 'korea').is_compliant);
});
test('H-01', '규격 데이터에 존재하지 않는 "ISO 19650:2026" 없음', () => {
  assert.ok(!JSON.stringify(REGULATIONS).includes('19650:2026'), 'ISO 19650:2026 잔존');
});
test('SRC-01', '규격 데이터 전 항목에 source(출처) 필드 존재', () => {
  for (const r of REGULATIONS) assert.ok(r.source && r.source.length > 3, `출처 누락: ${r.id}`);
});
test('H-06', '생성 스크립트에 가짜 API(surface.ProjectPoint) 없음', () => {
  for (const [k, t] of Object.entries(SCRIPT_TEMPLATES))
    assert.ok(!t.code('S1').includes('ProjectPoint'), `가짜 API 잔존: ${k}`);
});
test('H-07', 'Revit 템플릿은 Toposolid 기반 (deprecated TopographySurface 아님)', () => {
  const c = SCRIPT_TEMPLATES.revit_csharp.code('S1');
  assert.ok(c.includes('Toposolid'), 'Toposolid 미사용');
  assert.ok(!c.includes('typeof(TopographySurface)'), 'TopographySurface 수집 잔존');
});
test('H-08', 'Civil3D 템플릿: 코드(win32com)와 안내문(pywin32) 일치', () => {
  const t = SCRIPT_TEMPLATES.civil3d_python;
  assert.ok(t.code('S1').includes('win32com'), 'win32com 사용');
  assert.ok(t.instructions.join(' ').includes('pywin32'), '안내문 pywin32');
  assert.ok(!t.instructions.join(' ').includes('pyautocad'), 'pyautocad 잔존');
});
test('H-09', 'Dynamo 템플릿 과대표기("Steps 1-6") 제거, 실계산 OUT 반환', () => {
  const c = SCRIPT_TEMPLATES.dynamo.code('S1');
  assert.ok(!c.includes('Steps 1-6'), '과대표기 잔존');
  assert.ok(!c.includes('Script ready for execution'), '플레이스홀더 OUT 잔존');
});
test('B-08', '델로니 죽은 코드(px===undefined) 제거 확인', () => {
  assert.ok(!m[1].includes('px===undefined'), '죽은 코드 잔존');
});

// ---- ⑦ 보고 ----
console.log(`\n=== 결과: ${passed} PASS / ${failed} FAIL ===`);
process.exit(failed ? 1 : 0);
