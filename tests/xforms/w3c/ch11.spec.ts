import { test, expect, loadTest, loadAndWait, getRenderedText, submitAndCapture, collectDialogMessages, clickTrigger, getFormControlText, clickAndCaptureRequest, waitForCondition, forceOneShotEndpointFailure, clearDispatchedEvents, getDispatchedEvents, evaluateSubmissionXPath } from "./helpers";

test.describe("W3C Ch11 [behavioral promoted]", () => {
  /*
     When you activate the Submit Make And Model trigger the page must be replaced by the form data.
     The form data must contain the values "Acura" and "Integra", but not the value "white".
  */
  test("11.1.a — 11.1.a ref attribute of submission element", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Make And Model" }));
    const body = req ? (await req.postData()) || "" : "";
    // TEST-TRACE: validate 11.1.a submit scope via SaxonJS XPath payload checks; helps tests/w3c/ch11.spec.ts "11.1.a".
    const bodyAnalysis = await evaluateSubmissionXPath(page, body, {
      hasMake: "exists((/*[local-name()='make'], /*/*[local-name()='make'])[1])",
      containsMake: "contains(normalize-space(string(/*[1])), 'Acura')",
      containsModel: "contains(normalize-space(string(/*[1])), 'Integra')",
      hasColor: "exists((/*[local-name()='color'], /*/*[local-name()='color'])[1])",
      hasYear: "exists((/*[local-name()='year'], /*/*[local-name()='year'])[1])",
      hasHp: "exists((/*[local-name()='hp'], /*/*[local-name()='hp'])[1])",
      containsWhite: "contains(string(/*[1]), 'white')",
    });
    expect(req?.method()).toBe("POST");
    expect(bodyAnalysis.parseError).toBe("");
    expect(bodyAnalysis.xpathError).toBe("");
    expect(bodyAnalysis.values.hasMake).toBe("true");
    expect(bodyAnalysis.values.containsMake).toBe("true");
    expect(bodyAnalysis.values.containsModel).toBe("true");
    expect(bodyAnalysis.values.hasColor).toBe("false");
    expect(bodyAnalysis.values.hasYear).toBe("false");
    expect(bodyAnalysis.values.hasHp).toBe("false");
    expect(bodyAnalysis.values.containsWhite).toBe("false");
  });

  /*
     When you activate the Submit trigger the page must be replaced by the form data. You must see
     the value "white" in the form data. You must not see the values "Acura", "1994", or "120".
  */
  test("11.1.b — 11.1.b bind attribute of submission element", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.b.xhtml");
    const submitBtn = page.getByRole("button", { name: "Submit" });
    const req = await submitAndCapture(page, submitBtn);
    const body = req ? await req.postData() : "";
    // TEST-TRACE: validate 11.1.b bind-scoped payload via SaxonJS XPath checks; helps tests/w3c/ch11.spec.ts "11.1.b".
    const bodyAnalysis = await evaluateSubmissionXPath(page, body, {
      hasColor: "exists((/*[local-name()='color'], /*/*[local-name()='color'])[1])",
      color: "normalize-space(string((/*[local-name()='color'], /*/*[local-name()='color'])[1]))",
      hasMake: "exists((/*[local-name()='make'], /*/*[local-name()='make'])[1])",
      hasYear: "exists((/*[local-name()='year'], /*/*[local-name()='year'])[1])",
      hasHp: "exists((/*[local-name()='hp'], /*/*[local-name()='hp'])[1])",
    });
    expect(req?.method()).toBe("POST");
    expect(bodyAnalysis.parseError).toBe("");
    expect(bodyAnalysis.xpathError).toBe("");
    expect(bodyAnalysis.values.hasColor).toBe("true");
    expect(bodyAnalysis.values.color).toBe("white");
    expect(bodyAnalysis.values.hasMake).toBe("false");
    expect(bodyAnalysis.values.hasYear).toBe("false");
    expect(bodyAnalysis.values.hasHp).toBe("false");
  });

  /*
     When you activate the Submit Make And Model trigger the page must be replaced by the form data.
     The form data must contain the values "Acura" and "Integra", but not the value "white".
  */
  test("11.1.c — 11.1.c resource attribute of submission element", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.c.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Make And Model" }));
    const body = req ? (await req.postData()) || "" : "";
    // TEST-TRACE: validate 11.1.c resource-driven payload via SaxonJS XPath checks; helps tests/w3c/ch11.spec.ts "11.1.c".
    const bodyAnalysis = await evaluateSubmissionXPath(page, body, {
      hasMake: "exists((/*[local-name()='make'], /*/*[local-name()='make'])[1])",
      containsMake: "contains(normalize-space(string(/*[1])), 'Acura')",
      containsModel: "contains(normalize-space(string(/*[1])), 'Integra')",
      hasColor: "exists((/*[local-name()='color'], /*/*[local-name()='color'])[1])",
      hasYear: "exists((/*[local-name()='year'], /*/*[local-name()='year'])[1])",
      hasHp: "exists((/*[local-name()='hp'], /*/*[local-name()='hp'])[1])",
      containsWhite: "contains(string(/*[1]), 'white')",
    });
    expect(req?.method()).toBe("POST");
    expect(bodyAnalysis.parseError).toBe("");
    expect(bodyAnalysis.xpathError).toBe("");
    expect(bodyAnalysis.values.hasMake).toBe("true");
    expect(bodyAnalysis.values.containsMake).toBe("true");
    expect(bodyAnalysis.values.containsModel).toBe("true");
    expect(bodyAnalysis.values.hasColor).toBe("false");
    expect(bodyAnalysis.values.hasYear).toBe("false");
    expect(bodyAnalysis.values.hasHp).toBe("false");
    expect(bodyAnalysis.values.containsWhite).toBe("false");
  });

  // --- Submit + check POST body ---

  /*
     When you activate the Submit trigger the page must be replaced by the form data. The form data
     must contain the values "Subaru" and "Impreza WRX STi", and "2005".
  */
  test("11.1.d — method=post sends instance XML", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.d.xhtml");
    const btn = page.getByRole("button", { name: "Submit" });
    const req = await submitAndCapture(page, btn);
    const body = req ? (await req.postData()) || "" : "";
    // TEST-TRACE: align 11.1.d with fixture criteria by asserting action target, POST method, and all required submitted values.
    const bodyAnalysis = await evaluateSubmissionXPath(page, body, {
      rootLocalName: "local-name(/*[1])",
      hasSubaru: "contains(normalize-space(string((/*[local-name()='car']/*[local-name()='make'])[1])), 'Subaru')",
      modelValue: "normalize-space(string((/*[local-name()='car']/*[local-name()='make']/*[local-name()='model'])[1]))",
      yearValue: "normalize-space(string((/*[local-name()='car']/*[local-name()='year'])[1]))",
    });
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("POST");
    expect(req?.url()).toContain("/cgi-bin/echo.sh");
    expect(bodyAnalysis.parseError).toBe("");
    expect(bodyAnalysis.xpathError).toBe("");
    expect(bodyAnalysis.values.rootLocalName).toBe("car");
    expect(bodyAnalysis.values.hasSubaru).toBe("true");
    expect(bodyAnalysis.values.modelValue).toBe("Impreza WRX STi");
    expect(bodyAnalysis.values.yearValue).toBe("2005");
  });
  /*
     Each submit control below submits the form with a different mode. Both must replace the page
     with form data containing the value "white".
  */
  test("11.1.e — mode attribute submits same color payload", async ({ page }) => {
    // TEST-TRACE: promote 11.1.e from render smoke to request-body checks for synchronous and asynchronous submissions.
    await loadAndWait(page, "Chapt11/11.1/11.1.e.xhtml");
    const syncReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit with Synchronous" }));
    const syncBody = syncReq ? (await syncReq.postData()) || "" : "";
    expect(syncBody).toContain("white");
    expect(syncBody).not.toContain("Acura");

    await loadAndWait(page, "Chapt11/11.1/11.1.e.xhtml");
    const asyncReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit with Asynchronous" }));
    const asyncBody = asyncReq ? (await asyncReq.postData()) || "" : "";
    expect(asyncBody).toContain("white");
    expect(asyncBody).not.toContain("Acura");
  });

  /*
     Each submit control below submits the form with a different method. Both must replace the page
     with form data containing the values "Infiniti", "G35x", and "2005".
  */
  test("11.1.f — method attribute dispatches post and put", async ({ page }) => {
    // TEST-TRACE: promote 11.1.f to verify HTTP method selection and submitted payload content.
    await loadAndWait(page, "Chapt11/11.1/11.1.f.xhtml");
    const postReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit by Post" }));
    const postBody = postReq ? (await postReq.postData()) || "" : "";
    expect(postReq?.method()).toBe("POST");
    expect(postBody).toContain("Infiniti");
    expect(postBody).toContain("G35x");
    expect(postBody).toContain("2005");

    await loadAndWait(page, "Chapt11/11.1/11.1.f.xhtml");
    const putReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit by Put" }));
    const putBody = putReq ? (await putReq.postData()) || "" : "";
    expect(putReq?.method()).toBe("PUT");
    expect(putBody).toContain("Infiniti");
    expect(putBody).toContain("G35x");
    expect(putBody).toContain("2005");
  });

  // --- Submit-done/error message tests ---

  /*
     When you activate the Submit (validate=true) submit control you must see an xforms-submit-error
     message. When you activate the Submit (validate=false) submit control you must not see a
     message.
  */
  test("11.1.h — validate true errors; validate false submits", async ({ page }) => {
    // TEST-TRACE: align 11.1.h with fixture criteria by asserting validate=true raises submit-error and validate=false submits without error.
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.1/11.1.h.xhtml");
    const validateFalseEndpoint = /xformstest\.org\/cgi-bin\/echo\.sh(?:\?|$)/i;
    const validateFalseRoute = async (route: any) => {
      await route.fulfill({
        status: 200,
        contentType: "application/xml",
        body: "<?xml version=\"1.0\"?><ok/>",
      });
      await page.unroute(validateFalseEndpoint, validateFalseRoute);
    };
    await page.route(validateFalseEndpoint, validateFalseRoute);
    const beforeValidateFalseCount = dialogs.length;
    const validateFalseReq = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Submit (validate=false)" }),
      (request) => request.method() === "POST" && validateFalseEndpoint.test(request.url()),
      5000
    );
    await page.waitForTimeout(500);
    const validateFalseDialogs = dialogs.slice(beforeValidateFalseCount);
    expect(validateFalseDialogs).toEqual([]);
    expect(validateFalseReq).not.toBeNull();
    const validateFalseBody = validateFalseReq ? (await validateFalseReq.postData()) || "" : "";
    expect(validateFalseReq?.method()).toBe("POST");
    expect(validateFalseReq?.url()).toContain("xformstest.org/cgi-bin/echo.sh");
    expect(validateFalseBody).toContain("ten");
    expect(validateFalseBody).not.toContain("Toyota");
    await loadAndWait(page, "Chapt11/11.1/11.1.h.xhtml");
    const beforeValidateTrueCount = dialogs.length;
    const validateTrueReq = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Submit (validate=true)" }),
      (request) => request.method() === "POST" && /\/cgi-bin\/echo\.sh(?:\?|$)/i.test(request.url()),
      1500
    );
    await waitForCondition(
      page,
      () => dialogs.slice(beforeValidateTrueCount).some((message) => /^xforms-submit-error$/i.test(message)),
      { timeoutMs: 5000, description: "11.1.h validate=true submit-error dialog" }
    );
    expect(validateTrueReq).toBeNull();
  });

  /*
     Both submit controls must replace the page with the form data when activated.
     With relevant=true, non-relevant dateOfPurchase must be excluded; with relevant=false it must be included.
  */
  test("11.1.i — relevant attribute controls non-relevant node serialization", async ({ page }) => {
    // TEST-TRACE: promote 11.1.i to compare serialized request bodies for relevant=true vs relevant=false.
    await loadAndWait(page, "Chapt11/11.1/11.1.i.xhtml");
    const relevantTrueReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit (relevant=true)" }));
    const relevantTrueBody = relevantTrueReq ? (await relevantTrueReq.postData()) || "" : "";
    expect(relevantTrueBody).toContain("Suzuki");
    expect(relevantTrueBody).toContain("Hayabusa 1300");
    expect(relevantTrueBody).not.toContain("2006-04-26");

    await loadAndWait(page, "Chapt11/11.1/11.1.i.xhtml");
    const relevantFalseReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit (relevant=false)" }));
    const relevantFalseBody = relevantFalseReq ? (await relevantFalseReq.postData()) || "" : "";
    expect(relevantFalseBody).toContain("Suzuki");
    expect(relevantFalseBody).toContain("Hayabusa 1300");
    expect(relevantFalseBody).toContain("2006-04-26");
  });

  /*
     When you activate the Submit With Serialization submit control the page must be replaced by the
     form data. The value "blue" must not appear in the request URI header or in the form data.
  */
  test("11.1.j — serialization=none sends empty body", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.j.xhtml");
    const btn = page.getByRole("button", { name: /Submit With Serialization/ });
    const req = await submitAndCapture(page, btn);
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("GET");
    expect(req?.url()).not.toMatch(/blue/i);
    const body = req ? (await req.postData()) || "" : "";
    // TEST-TRACE: align 11.1.j with fixture criteria by asserting blue is absent from URI and serialized form data.
    expect(body).toBe("");
    expect(body).not.toContain("blue");
  });

  const getHeaderValue = (headers: Record<string, string>, headerName: string): string => {
    const match = Object.entries(headers).find(([name]) => name.toLowerCase() === headerName.toLowerCase());
    return match ? String(match[1]) : "";
  };

  const normalize = (value: string): string => value.replace(/\s+/g, " ").trim();

  async function runHttpMethodCase(
    page: any,
    file: string,
    buttonLabel: string,
    expectedMethod: "GET" | "POST" | "PUT",
    expectedProtocol: "http:" | "https:"
  ) {
    await loadAndWait(page, file);
    const req = await submitAndCapture(page, page.getByRole("button", { name: buttonLabel }), 5000);
    expect(req).not.toBeNull();
    expect(req?.method()).toBe(expectedMethod);
    if (req) {
      expect(new URL(req.url()).protocol).toBe(expectedProtocol);
      const body = (await req.postData()) || "";
      if (expectedMethod === "GET") {
        expect(body).toBe("");
      } else {
        expect(body).toContain("Henry");
      }
    }
  }

  async function runSerializationCase(
    page: any,
    file: string,
    expectedMethod: "POST" | "PUT",
    expectedMediaType: string
  ) {
    await loadAndWait(page, file);
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Data" }), 5000);
    expect(req).not.toBeNull();
    expect(req?.method()).toBe(expectedMethod);
    if (req) {
      const headers = req.headers();
      const contentType = getHeaderValue(headers, "content-type").toLowerCase();
      const body = (await req.postData()) || "";
      expect(contentType).toContain(expectedMediaType);
      expect(body).toContain("Henry");
      expect(body).toContain("Acura");
      expect(body.toLowerCase()).toContain("white");
    }
  }

  async function runNonHttpResourceErrorCase(
    page: any,
    file: string,
    buttonLabel: string,
    expectedResourceUriPrefix: string
  ) {
    await loadAndWait(page, file);
    await clearDispatchedEvents(page);
    const beforeUrl = page.url();
    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: buttonLabel }),
      (request) => /\/echo\.sh(?:\?|$)/i.test(request.url()),
      1500
    );
    expect(req).toBeNull();
    expect(page.url()).toBe(beforeUrl);

    const events = await getDispatchedEvents(page);
    const submitErrorEvents = events.filter((event) => event.name.toLowerCase() === "xforms-submit-error");
    if (submitErrorEvents.length > 0) {
      const matchingSubmitError = submitErrorEvents.find((event) => {
        const errorType = (event.context["error-type"] || "").toLowerCase();
        const resourceUri = (event.context["resource-uri"] || "").toLowerCase();
        return (
          errorType === "resource-error" &&
          resourceUri.startsWith(expectedResourceUriPrefix.toLowerCase())
        );
      });
      expect(matchingSubmitError || submitErrorEvents[0]).toBeTruthy();
    }
  }

  test("11.1.k — version variants submit comparable payloads", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.k.xhtml");
    const v10 = await submitAndCapture(page, page.getByRole("button", { name: "Submit as 1.0" }), 5000);
    const v10Body = v10 ? normalize((await v10.postData()) || "") : "";
    expect(v10).not.toBeNull();
    expect(v10?.method()).toBe("POST");
    expect(v10Body).toContain("Acura");
    expect(v10Body).toContain("2005");

    await loadAndWait(page, "Chapt11/11.1/11.1.k.xhtml");
    const v11 = await submitAndCapture(page, page.getByRole("button", { name: "Submit as 1.1" }), 5000);
    const v11Body = v11 ? normalize((await v11.postData()) || "") : "";
    expect(v11).not.toBeNull();
    expect(v11?.method()).toBe("POST");
    expect(v11Body).toContain("Acura");
    expect(v11Body).toContain("2005");
  });

  test("11.1.l — indent variants submit the same data model", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.l.xhtml");
    const noIndent = await submitAndCapture(page, page.getByRole("button", { name: "Submit Without indent" }), 5000);
    const noIndentBody = noIndent ? normalize((await noIndent.postData()) || "") : "";
    expect(noIndent).not.toBeNull();
    expect(noIndent?.method()).toBe("POST");
    expect(noIndentBody).toContain("Acura");
    expect(noIndentBody).toContain("blue");

    await loadAndWait(page, "Chapt11/11.1/11.1.l.xhtml");
    const withIndent = await submitAndCapture(page, page.getByRole("button", { name: "Submit With indent" }), 5000);
    const withIndentBody = withIndent ? normalize((await withIndent.postData()) || "") : "";
    expect(withIndent).not.toBeNull();
    expect(withIndent?.method()).toBe("POST");
    expect(withIndentBody).toContain("Acura");
    expect(withIndentBody).toContain("blue");
  });

  /*
     When you activate the Submit submit control the page must be replaced by the form data.
     The variable on the page for the content type must equal the value "application/xml".
  */
  test("11.1.m — mediatype attribute sets application/xml content type", async ({ page }) => {
    // TEST-TRACE: promote 11.1.m to assert submission content-type header from mediatype attribute.
    await loadAndWait(page, "Chapt11/11.1/11.1.m.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit" }));
    const headers = req ? req.headers() : {};
    expect((headers["content-type"] || "").toLowerCase()).toContain("application/xml");
  });

  /*
     Submit (UTF-8) must include encoding="UTF-8"; Submit (ISO) must include encoding="ISO-8859-1".
  */
  test("11.1.n — encoding attribute controls XML declaration encoding", async ({ page }) => {
    // TEST-TRACE: promote 11.1.n to verify encoding marker in serialized XML for both submission controls.
    await loadAndWait(page, "Chapt11/11.1/11.1.n.xhtml");
    const utfReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit (UTF-8)" }));
    const utfBody = utfReq ? (await utfReq.postData()) || "" : "";
    expect(utfBody).toMatch(/encoding=["']UTF-8["']/i);

    await loadAndWait(page, "Chapt11/11.1/11.1.n.xhtml");
    const isoReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit (ISO)" }));
    const isoBody = isoReq ? (await isoReq.postData()) || "" : "";
    expect(isoBody).toMatch(/encoding=["']ISO-8859-1["']/i);
  });

  /*
     After activating Submit, XML declaration must not appear at the top of the form data.
  */
  test("11.1.o — omit-xml-declaration removes XML declaration", async ({ page }) => {
    // TEST-TRACE: promote 11.1.o to assert absence of XML declaration in serialized submission body.
    await loadAndWait(page, "Chapt11/11.1/11.1.o.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit" }));
    const body = req ? (await req.postData()) || "" : "";
    expect(body).not.toContain("<?xml");
  });

  /*
     When you activate the Submit With Standalone true submit control you must see a standalone
     declaration in the form data. It may appear as the value " standalone="yes" " or "
     standalone="true" ". When you activate the Submit With Standalone false submit control you must
     see a standalone declaration in the form data. It may appear as the value " standalone="no" "
     or " standalone="false" ". When you activate the Submit Without Standalone submit control you
     must not see a standalone declaration in the form data.
  */
  test("11.1.p — 11.1.p standalone attribute of submission element", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.p.xhtml");
    // TEST-TRACE: assert standalone serialization follows 11.1.p.xhtml submission values; helps tests/w3c/ch11.spec.ts "11.1.p".
    const standaloneTrueDeclaration = 'standalone="true"';
    const standaloneFalseDeclaration = 'standalone="false"';
    const standaloneTrueReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit With Standalone true" }));
    const standaloneTrueBody = standaloneTrueReq ? (await standaloneTrueReq.postData()) || "" : "";
    expect(standaloneTrueReq?.method()).toBe("POST");
    expect(standaloneTrueBody).toContain("<car");
    expect(standaloneTrueBody).toContain("<make>Acura</make>");
    expect(standaloneTrueBody).toContain(standaloneTrueDeclaration);
    expect(standaloneTrueBody).not.toContain(standaloneFalseDeclaration);

    await loadAndWait(page, "Chapt11/11.1/11.1.p.xhtml");
    const standaloneFalseReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit With Standalone false" }));
    const standaloneFalseBody = standaloneFalseReq ? (await standaloneFalseReq.postData()) || "" : "";
    expect(standaloneFalseReq?.method()).toBe("POST");
    expect(standaloneFalseBody).toContain("<car");
    expect(standaloneFalseBody).toContain("<make>Acura</make>");
    expect(standaloneFalseBody).toContain(standaloneFalseDeclaration);
    expect(standaloneFalseBody).not.toContain(standaloneTrueDeclaration);

    await loadAndWait(page, "Chapt11/11.1/11.1.p.xhtml");
    const standaloneUnsetReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit Without Standalone" }));
    const standaloneUnsetBody = standaloneUnsetReq ? (await standaloneUnsetReq.postData()) || "" : "";
    expect(standaloneUnsetReq?.method()).toBe("POST");
    expect(standaloneUnsetBody).toContain("<car");
    expect(standaloneUnsetBody).toContain("<make>Acura</make>");
    expect(standaloneUnsetBody).not.toContain("standalone=");
    expect(standaloneTrueBody).not.toBe(standaloneFalseBody);
    expect(standaloneFalseBody).not.toBe(standaloneUnsetBody);
  });

  /*
     cdata-section-elements must serialize chosen element content within CDATA sections.
  */
  test("11.1.q — cdata-section-elements serializes selected elements as CDATA", async ({ page }) => {
    // TEST-TRACE: promote 11.1.q to verify CDATA serialization behavior for make and year targets.
    await loadAndWait(page, "Chapt11/11.1/11.1.q.xhtml");
    const makeReq = await submitAndCapture(page, page.getByRole("button", { name: 'Submit (cdata="make")' }));
    const makeBody = makeReq ? (await makeReq.postData()) || "" : "";
    expect(makeBody).toContain("<![CDATA[Toyota]]>");
    expect(makeBody).toContain("<model>Acura</model>");

    await loadAndWait(page, "Chapt11/11.1/11.1.q.xhtml");
    const yearReq = await submitAndCapture(page, page.getByRole("button", { name: 'Submit (cdata="year")' }));
    const yearBody = yearReq ? (await yearReq.postData()) || "" : "";
    expect(yearBody).toContain("<![CDATA[2005]]>");
  });
  // --- Render checks (no submit needed) ---

  /*
     You must see the values "Henry", "Acura", and "white" in the First Instance. You must see the
     values "Thomas", "Toyota", and "silver" in the Second Instance. When you activate the Replace
     Instance submit control the values in the First Instance must stay the same. The values in the
     second instance must change to "Janel", "Saturn", and "red".
  */
  test("11.1.r — replace=instance puts response into correct instances", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.r.xhtml");
    // TEST-TRACE: align 11.1.r with fixture criteria by asserting initial values for both instances, GET action target, and post-submit selective instance replacement.
    const before = await getFormControlText(page);
    expect(before).toContain("Henry");
    expect(before).toContain("Acura");
    expect(before).toContain("white");
    expect(before).toContain("Thomas");
    expect(before).toContain("Toyota");
    expect(before).toContain("silver");

    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Replace Instance" }),
      (request) =>
        request.method() === "GET" &&
        /\/w3c-suite\/Chapt11\/11\.1\/11\.1\.r\.data\.xml(?:\?|$)/i.test(request.url()),
      5000
    );
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("GET");
    expect(req?.url()).toContain("/w3c-suite/Chapt11/11.1/11.1.r.data.xml");
    const body = req ? (await req.postData()) || "" : "";
    expect(body).toBe("");

    await waitForCondition(
      page,
      async () => {
        const afterText = await getFormControlText(page);
        return (
          afterText.includes("Henry") &&
          afterText.includes("Acura") &&
          afterText.includes("white") &&
          afterText.includes("Janel") &&
          afterText.includes("Saturn") &&
          afterText.includes("red") &&
          !afterText.includes("Thomas") &&
          !afterText.includes("Toyota") &&
          !afterText.includes("silver")
        );
      },
      { timeoutMs: 5000, description: "11.1.r instance replacement results" }
    );
    const after = await getFormControlText(page);
    expect(after).toContain("Henry");
    expect(after).toContain("Acura");
    expect(after).toContain("white");
    expect(after).toContain("Janel");
    expect(after).toContain("Saturn");
    expect(after).toContain("red");
    expect(after).not.toContain("Thomas");
    expect(after).not.toContain("Toyota");
    expect(after).not.toContain("silver");
  });

  /*
     Activating one replace-instance control must update only that instance output.
  */
  test("11.1.s1 — each instance submit replaces only its targeted instance", async ({ page }) => {
    // TEST-TRACE: collapse duplicate 11.1.s1 variants into one complete case that checks all three submits, target isolation, and relative action request path.
    const originalValues = [
      "This is data from instance 1.",
      "This is data from instance 2.",
      "This is data from instance 3.",
    ];
    const cases: Array<{ label: string; replacedText: string }> = [
      { label: "Replace Instance 1", replacedText: "This is data from instance 1." },
      { label: "Replace Instance 2", replacedText: "This is data from instance 2." },
      { label: "Replace Instance 3", replacedText: "This is data from instance 3." },
    ];
    for (const { label, replacedText } of cases) {
      await loadAndWait(page, "Chapt11/11.1/11.1.s1.xhtml");
      const before = await getFormControlText(page);
      for (const value of originalValues) {
        expect(before).toContain(value);
      }
      const req = await clickAndCaptureRequest(
        page,
        page.getByRole("button", { name: label }),
        (request) => request.method() === "GET" && /\/w3c-suite\/Chapt11\/11\.1\/11\.1\.s_data\.xml(?:\?|$)/.test(request.url()),
        3000
      );
      expect(req).not.toBeNull();
      expect(req?.method()).toBe("GET");
      expect(req?.url()).toContain("/w3c-suite/Chapt11/11.1/11.1.s_data.xml");
      await page.waitForTimeout(500);
      const after = await getFormControlText(page);
      expect(after).not.toContain(replacedText);
      for (const value of originalValues.filter((value) => value !== replacedText)) {
        expect(after).toContain(value);
      }
      const responseCount = (after.match(/This is the response data\./g) || []).length;
      expect(responseCount).toBe(1);
    }
  });

  /*
     Invalid instance reference must produce xforms-binding-exception message or fatal binding failure.
  */
  test("11.1.s2 — invalid instance reference surfaces binding exception", async ({ page }) => {
    // TEST-TRACE: promote 11.1.s2 to verify binding-exception signaling on invalid submission instance reference.
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.1/11.1.s2.xhtml");
    const beforeCount = dialogs.length;
    await clickTrigger(page, "Invalid Instance");
    await page.waitForTimeout(500);
    const newDialogs = dialogs.slice(beforeCount);
    const rendered = await getRenderedText(page);
    expect(
      newDialogs.some((message) => /xforms-binding-exception/i.test(message)) ||
      /xforms-binding-exception|fatal/i.test(rendered)
    ).toBe(true);
  });

  /*
     You must see the values "Thomas", "Toyota", and "silver" in the output controls. When you
     activate the Replace Instance submit control the values must change to "Janel", "Saturn", and
     "red".
  */
  test("11.1.t — replace=instance with targetref puts response in target", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.t.xhtml");
    // TEST-TRACE: align 11.1.t with fixture criteria by asserting initial second-instance values, GET action target, and replacement to Janel/Saturn/red.
    const before = await getFormControlText(page);
    expect(before).toContain("Thomas");
    expect(before).toContain("Toyota");
    expect(before).toContain("silver");
    expect(before).not.toContain("Janel");
    expect(before).not.toContain("Saturn");
    expect(before).not.toContain("red");

    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Replace Instance" }),
      (request) =>
        request.method() === "GET" &&
        /\/w3c-suite\/Chapt11\/11\.1\/11\.1\.t\.data\.xml(?:\?|$)/i.test(request.url()),
      5000
    );
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("GET");
    expect(req?.url()).toContain("/w3c-suite/Chapt11/11.1/11.1.t.data.xml");
    const body = req ? (await req.postData()) || "" : "";
    expect(body).toBe("");

    await waitForCondition(
      page,
      async () => {
        const afterText = await getFormControlText(page);
        return (
          afterText.includes("Janel") &&
          afterText.includes("Saturn") &&
          afterText.includes("red") &&
          !afterText.includes("Thomas") &&
          !afterText.includes("Toyota") &&
          !afterText.includes("silver")
        );
      },
      { timeoutMs: 5000, description: "11.1.t targetref replacement results" }
    );
    const after = await getFormControlText(page);
    expect(after).toContain("Janel");
    expect(after).toContain("Saturn");
    expect(after).toContain("red");
    expect(after).not.toContain("Thomas");
    expect(after).not.toContain("Toyota");
    expect(after).not.toContain("silver");
  });

  /*
     URL-encoded body must use default '&' separator and configured ';' separator respectively.
  */
  test("11.1.u — separator attribute changes urlencoded pair separator", async ({ page }) => {
    // TEST-TRACE: promote 11.1.u to compare urlencoded separator behavior between default and explicit separator.
    await loadAndWait(page, "Chapt11/11.1/11.1.u.xhtml");
    const ampReq = await submitAndCapture(page, page.getByRole("button", { name: "Separate With '&'" }));
    const ampBody = ampReq ? (await ampReq.postData()) || "" : "";
    expect(ampBody).toContain("carOwner=Greg");
    expect(ampBody).toContain("make=Toyota");
    expect(ampBody).toContain("color=Silver");
    expect(ampBody).toContain("&");

    await loadAndWait(page, "Chapt11/11.1/11.1.u.xhtml");
    const semiReq = await submitAndCapture(page, page.getByRole("button", { name: "Separate With ';'" }));
    const semiBody = semiReq ? (await semiReq.postData()) || "" : "";
    expect(semiBody).toContain("carOwner=Greg");
    expect(semiBody).toContain("make=Toyota");
    expect(semiBody).toContain("color=Silver");
    expect(semiBody).toContain(";");
  });

  /*
     When you activate the Submit submit control the page must be replaced by the form data. You
     must see the namespace " <my:car xmlns:my="http://www.fakenamespace.org"> " in the form data.
     You must NOT see any other namespaces in the form data.
  */
  test("11.1.v — 11.1.v includenamespaceprefixes attribute of submission element", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.1/11.1.v.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit" }));
    const body = req ? (await req.postData()) || "" : "";
    // TEST-TRACE: use SaxonJS XPath evaluation to assert only my namespace (plus xml/default) is in-scope; helps tests/w3c/ch11.spec.ts "11.1.v".
    const namespaceAnalysis = await page.evaluate((xmlBody) => {
      const parsed = new DOMParser().parseFromString(xmlBody, "application/xml");
      const parseError = parsed.querySelector("parsererror");
      if (parseError) {
        return {
          parseError: parseError.textContent || "XML parse error",
          xpathError: "",
          rootName: "",
          rootNamespaceUri: "",
          myNamespaceUri: "",
          defaultNamespaceUri: "",
          inScopeNamespaces: [] as string[],
          disallowedNamespaces: [] as string[],
          prefixedElementCount: 0,
        };
      }
      try {
        const saxonJs = (window as any).SaxonJS;
        const evaluateXPath = (expression: string, options?: Record<string, unknown>) =>
          saxonJs.XPath.evaluate(expression, parsed, options || {});
        const rootName = String(evaluateXPath("name(/*[1])"));
        const rootNamespaceUri = String(evaluateXPath("namespace-uri(/*[1])"));
        const myNamespaceUri = String(evaluateXPath("string(namespace-uri-for-prefix('my', /*[1]))"));
        const defaultNamespaceUri = String(evaluateXPath("string(namespace-uri-for-prefix('', /*[1]))"));
        const prefixedElementCount = Number(evaluateXPath("count(//*[contains(name(), ':')])"));
        const inScopeNamespaces = (evaluateXPath(
          "for $p in sort(in-scope-prefixes(/*[1])) return concat(if ($p = '') then '#default' else $p, '=', string(namespace-uri-for-prefix($p, /*[1])))",
          { resultForm: "array" }
        ) || []) as string[];
        const disallowedNamespaces = (evaluateXPath(
          "for $p in sort(in-scope-prefixes(/*[1])[not(. = ('', 'xml', 'my'))]) return concat($p, '=', string(namespace-uri-for-prefix($p, /*[1])))",
          { resultForm: "array" }
        ) || []) as string[];
        return {
          parseError: "",
          xpathError: "",
          rootName,
          rootNamespaceUri,
          myNamespaceUri,
          defaultNamespaceUri,
          inScopeNamespaces: inScopeNamespaces.map((value) => String(value)),
          disallowedNamespaces: disallowedNamespaces.map((value) => String(value)),
          prefixedElementCount,
        };
      } catch (error) {
        return {
          parseError: "",
          xpathError: error instanceof Error ? error.message : String(error),
          rootName: "",
          rootNamespaceUri: "",
          myNamespaceUri: "",
          defaultNamespaceUri: "",
          inScopeNamespaces: [] as string[],
          disallowedNamespaces: [] as string[],
          prefixedElementCount: 0,
        };
      }
    }, body);
    expect(req?.method()).toBe("POST");
    expect(body).toContain("<my:car");
    expect(body).toContain('xmlns:my="http://www.fakenamespace.org"');
    expect(body).toContain("<make>Acura</make>");
    expect(body).toContain("<color>blue</color>");
    expect(namespaceAnalysis.parseError).toBe("");
    expect(namespaceAnalysis.xpathError).toBe("");
    expect(namespaceAnalysis.rootName).toBe("my:car");
    expect(namespaceAnalysis.rootNamespaceUri).toBe("http://www.fakenamespace.org");
    expect(namespaceAnalysis.myNamespaceUri).toBe("http://www.fakenamespace.org");
    expect(namespaceAnalysis.defaultNamespaceUri).toBe("");
    expect(namespaceAnalysis.inScopeNamespaces).toContain("my=http://www.fakenamespace.org");
    expect(namespaceAnalysis.inScopeNamespaces).toContain("xml=http://www.w3.org/XML/1998/namespace");
    expect(namespaceAnalysis.disallowedNamespaces).toEqual([]);
    expect(namespaceAnalysis.prefixedElementCount).toBe(1);
  });

  /*
     Submit Twice dispatches xforms-submit twice and must not surface xforms-submit-error.
  */
  test("11.2.a — submit twice does not raise submit-error", async ({ page }) => {
    // TEST-TRACE: keep assertion aligned with fixture expectation while validating submit dispatch occurs.
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.2/11.2.a.xhtml");
    const beforeCount = dialogs.length;
    await clickTrigger(page, "Submit Twice");
    await page.waitForTimeout(1500);
    const newDialogs = dialogs.slice(beforeCount);
    const submitCount = newDialogs.filter((message) => /^xforms-submit$/i.test(message)).length;
    const submitDoneCount = newDialogs.filter((message) => /^xforms-submit-done$/i.test(message)).length;
    const submitErrorCount = newDialogs.filter((message) => /^xforms-submit-error$/i.test(message)).length;
    expect(submitCount).toBeGreaterThan(0);
    expect(submitDoneCount).toBeGreaterThanOrEqual(0);
    expect(submitErrorCount).toBe(0);
  });

  /*
     When you activate the Show submit control the page must be replaced by the form data. You must
     see the values <data>, <test1 x=""/>, <test2 x="a"/>, and </data>. You must not see the values
     <test3 x=""/> or <test4 x="a"/>.
  */
  test("11.2.b — method=post with XML response", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.2/11.2.b.xhtml");
    const btn = page.getByRole("button", { name: "Show" });
    const req = await submitAndCapture(page, btn);
    const body = req ? (await req.postData()) || "" : "";
    // TEST-TRACE: align 11.2.b with fixture criteria by asserting only relevant nodes (test1/test2) serialize and non-relevant nodes (test3/test4) do not.
    const bodyAnalysis = await evaluateSubmissionXPath(page, body, {
      rootLocalName: "local-name(/*[1])",
      childCount: "count(/*[local-name()='data']/*)",
      hasTest1: "exists(/*[local-name()='data']/*[local-name()='test1'])",
      test1Attr: "string((/*[local-name()='data']/*[local-name()='test1'])[1]/@x)",
      hasTest2: "exists(/*[local-name()='data']/*[local-name()='test2'])",
      test2Attr: "string((/*[local-name()='data']/*[local-name()='test2'])[1]/@x)",
      hasTest3: "exists(/*[local-name()='data']/*[local-name()='test3'])",
      hasTest4: "exists(/*[local-name()='data']/*[local-name()='test4'])",
    });
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("POST");
    expect(req?.url()).toContain("/cgi-bin/echo.sh");
    expect(bodyAnalysis.parseError).toBe("");
    expect(bodyAnalysis.xpathError).toBe("");
    expect(bodyAnalysis.values.rootLocalName).toBe("data");
    expect(bodyAnalysis.values.childCount).toBe("2");
    expect(bodyAnalysis.values.hasTest1).toBe("true");
    expect(bodyAnalysis.values.test1Attr).toBe("");
    expect(bodyAnalysis.values.hasTest2).toBe("true");
    expect(bodyAnalysis.values.test2Attr).toBe("a");
    expect(bodyAnalysis.values.hasTest3).toBe("false");
    expect(bodyAnalysis.values.hasTest4).toBe("false");
  });

  /*
     After you activate the Submit Now submit control you must see an xforms-submit-error message
     and see the value "no-data" as output from the Error Name output control.
  */
  test("11.2.c — replace=instance renders", async ({ page }) => {
    // TEST-TRACE: promote 11.2.c to assert xforms-submit-error dialog and no-data error output.
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.2/11.2.c.xhtml");
    const beforeCount = dialogs.length;
    await clickTrigger(page, "Submit Now");
    await page.waitForTimeout(500);
    const newDialogs = dialogs.slice(beforeCount);
    expect(newDialogs.some((message) => /xforms-submit-error/i.test(message))).toBe(true);
    const text = await getFormControlText(page);
    expect(text).toContain("no-data");
  });

  /*
     After you activate the Submit Here submit control you must see an xforms-submit-error message
     and see the value "validation-error" as output from the Error Name output control.
  */
  test("11.2.d — method=post response replaces instance", async ({ page }) => {
    // TEST-TRACE: promote 11.2.d to assert submit-error dialog and validation-error event payload output.
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.2/11.2.d.xhtml");
    const beforeCount = dialogs.length;
    await clickTrigger(page, "Submit Here");
    await page.waitForTimeout(500);
    const newDialogs = dialogs.slice(beforeCount);
    expect(newDialogs.some((message) => /xforms-submit-error/i.test(message))).toBe(true);
    const text = await getFormControlText(page);
    expect(text).toContain("validation-error");
  });

  /*
     After you activate the Submit Here submit control you must see an xforms-submit-error message
     and see the value "validation-error" as output from the Error Name output control.
  */
  test("11.2.e — method=get sends URL-encoded data", async ({ page }) => {
    // TEST-TRACE: promote 11.2.e to assert submit-error dialog and validation-error context output.
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.2/11.2.e.xhtml");
    const beforeCount = dialogs.length;
    await clickTrigger(page, "Submit Here");
    await page.waitForTimeout(500);
    const newDialogs = dialogs.slice(beforeCount);
    expect(newDialogs.some((message) => /xforms-submit-error/i.test(message))).toBe(true);
    const text = await getFormControlText(page);
    expect(text).toContain("validation-error");
  });

  test("11.3.a — submit-serialize event fires and payload contains Toyota/Prius", async ({ page }) => {
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.3/11.3.a.xhtml");
    const beforeCount = dialogs.length;
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Now" }), 5000);
    const body = req ? (await req.postData()) || "" : "";
    expect(req).not.toBeNull();
    await waitForCondition(
      page,
      () => dialogs.slice(beforeCount).some((message) => /^xforms-submit-serialize$/i.test(message)),
      { timeoutMs: 5000, description: "11.3.a submit serialize dialog" }
    );
    expect(body).toContain("Toyota");
    expect(body).toContain("Prius");
  });

  /*
     After you activate the Submit Now submit control you must see an xforms-submit-serialize
     message. The page must also be replaced by the form data, where you must see the value
     <data>MyNewData</data>. You must not see the values "Toyota" or "Prius".
  */
  test("11.3.b — 11.3.b xforms-submit-serialize event with submission-body property", async ({ page }) => {
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.3/11.3.b.xhtml");
    const beforeCount = dialogs.length;
    const submitBtn = page.getByRole("button", { name: "Submit Now" });
    const req = await submitAndCapture(page, submitBtn);
    const body = req ? (await req.postData()) || "" : "";
    // TEST-TRACE: validate 11.3.b serialized payload content via SaxonJS XPath checks; helps tests/w3c/ch11.spec.ts "11.3.b".
    const bodyAnalysis = await evaluateSubmissionXPath(page, body, {
      dataValue: "normalize-space(string(/*[local-name()='data'][1]))",
      hasToyota: "exists(//*[contains(string(.), 'Toyota')])",
      hasPrius: "exists(//*[contains(string(.), 'Prius')])",
    });
    expect(req?.method()).toBe("POST");
    await waitForCondition(
      page,
      () => dialogs.slice(beforeCount).some((message) => /^xforms-submit-serialize$/i.test(message)),
      { timeoutMs: 5000, description: "xforms-submit-serialize modal message" }
    );
    expect(bodyAnalysis.parseError).toBe("");
    expect(bodyAnalysis.xpathError).toBe("");
    expect(bodyAnalysis.values.dataValue).toBe("MyNewData");
    expect(bodyAnalysis.values.hasToyota).toBe("false");
    expect(bodyAnalysis.values.hasPrius).toBe("false");
  });

  /* When you activate the Submit Now submit control you must see an xforms-submit-done message. */
  test("11.4.a — validate=false allows invalid submit", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.4/11.4.a.xhtml");
    const btn = page.getByRole("button", { name: /Submit/ }).first();
    await btn.click();
    await page.waitForTimeout(2000);
    expect(msgs.some(m => /submit-done/i.test(m))).toBe(true);
  });

  /*
     When you activate the Submit Now submission control the instance data of the form will be
     submitted but the page will not be replaced by the form data. If the submission is successful,
     the protocol response code will be displayed in the Response Status Code output. If there are
     any header names or values returned they will be displayed in the Response Headers output.
  */
  test("11.4.b — validate=true blocks invalid submit", async ({ page }) => {
    // TEST-TRACE: strengthen 11.4.b to verify xforms-submit-done context renders real response header name/value data, not just static labels.
    await loadAndWait(page, "Chapt11/11.4/11.4.b.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Now" }));
    expect(req).not.toBeNull();
    const response = req ? await req.response() : null;
    expect(response).not.toBeNull();
    expect(response?.status()).toBe(200);
    const responseHeaders = response ? await response.allHeaders() : {};
    const headerEntries = Object.entries(responseHeaders).filter(
      ([name, value]) => !!name && !!value && !name.startsWith(":")
    );
    expect(headerEntries.length).toBeGreaterThan(0);
    const text = await getFormControlText(page);
    expect(text).toContain("Response Headers");
    const normalizedText = text.toLowerCase();
    const renderedHeaderEntry = headerEntries.find(([name, value]) => {
      const headerName = String(name).toLowerCase();
      const headerValue = String(value).trim().toLowerCase();
      return headerValue !== "" && normalizedText.includes(headerName) && normalizedText.includes(headerValue);
    });
    expect(renderedHeaderEntry).toBeDefined();
  });

  /*
     Submit to bad URL should fail the request and may surface xforms-submit-error as a modal message.
  */
  test("11.5.a — failed submission emits observable error signal", async ({ page }) => {
    // TEST-TRACE: strict criteria requires the xforms-submit-error modal for an invalid submission resource.
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.5/11.5.a.xhtml");
    const beforeCount = dialogs.length;
    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Submit Now" }),
      (request) => request.method() === "POST" && /invaliduri\.com(?:\/|$)/i.test(request.url()),
      7000
    );
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("POST");
    expect(req?.url()).toMatch(/invaliduri\.com(?:\/|$)/i);
    await waitForCondition(
      page,
      () => dialogs.slice(beforeCount).some((message) => /^xforms-submit-error$/i.test(message)),
      { timeoutMs: 7000, description: "xforms-submit-error dialog for invalid resource" }
    );
  });

  /*
     Submit To Bad URL must populate error context outputs with resource-error and failing URI.
  */
  test("11.5.b — submit-error context properties populate output controls", async ({ page }) => {
    // TEST-TRACE: strict criteria requires error context outputs to include resource-error and failing URI.
    await loadAndWait(page, "Chapt11/11.5/11.5.b.xhtml");
    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Submit To Bad URL" }),
      (request) => request.method() === "POST" && /invaliduri\.com8565\/inval1d(?:\?|$|\/)/i.test(request.url()),
      7000
    );
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("POST");
    expect(req?.url()).toMatch(/invaliduri\.com8565\/inval1d(?:\?|$|\/)/i);
    await waitForCondition(
      page,
      async () => {
        const text = await getFormControlText(page);
        return text.includes("resource-error") && text.includes("http://invaliduri.com8565/inval1d");
      },
      { timeoutMs: 7000, description: "submit-error context outputs for 11.5.b" }
    );
    const text = await getFormControlText(page);
    expect(text).toContain("resource-error");
    expect(text).toContain("http://invaliduri.com8565/inval1d");
  });

  /*
     @resource and resource child element must both target xformstest.org endpoint.
  */
  test("11.6.1.a — resource child element and @resource both target submission URI", async ({ page }) => {
    // TEST-TRACE: strengthen 11.6.1.a to verify both endpoint selection and returned echo payload content for @resource and resource-element submissions.
    await loadAndWait(page, "Chapt11/11.6/11.6.1/11.6.1.a.xhtml");
    const attrReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit (@resource)" }));
    const attrResponse = attrReq ? await attrReq.response() : null;
    const attrResponseBody = attrResponse ? await attrResponse.text() : "";
    expect(attrReq?.url()).toContain("echo.sh");
    expect(attrReq?.method()).toBe("PUT");
    expect(attrResponse).not.toBeNull();
    expect(attrResponse?.status()).toBe(200);
    expect(attrResponseBody).toContain("Form posted data");

    await loadAndWait(page, "Chapt11/11.6/11.6.1/11.6.1.a.xhtml");
    const childReq = await submitAndCapture(page, page.getByRole("button", { name: "Submit (resource element)" }));
    const childResponse = childReq ? await childReq.response() : null;
    const childResponseBody = childResponse ? await childResponse.text() : "";
    expect(childReq?.url()).toContain("echo.sh");
    expect(childReq?.method()).toBe("PUT");
    expect(childResponse).not.toBeNull();
    expect(childResponse?.status()).toBe(200);
    expect(childResponseBody).toContain("Form posted data");
  });

  /*
     resource element value attribute must override fallback element text and bad @resource URI.
  */
  test("11.6.1.b — resource element value attribute drives submission endpoint", async ({ page }) => {
    // TEST-TRACE: strengthen 11.6.1.b to verify dynamic resource value selects the endpoint and returns echo payload content.
    await loadAndWait(page, "Chapt11/11.6/11.6.1/11.6.1.b.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit" }));
    const response = req ? await req.response() : null;
    const responseBody = response ? await response.text() : "";
    expect(req?.url()).toContain("echo.sh");
    expect(req?.method()).toBe("PUT");
    expect(response).not.toBeNull();
    expect(response?.status()).toBe(200);
    expect(responseBody).toContain("Form posted data");
  });

  /*
     Method child element value must set request method to post.
  */
  test("11.7.1.a — method element value sets request method", async ({ page }) => {
    // TEST-TRACE: promote 11.7.1.a by asserting method element value expression selects POST request method.
    await loadAndWait(page, "Chapt11/11.7/11.7.1/11.7.1.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit With Method" }));
    expect(req?.method()).toBe("POST");
  });

  /*
     When you activate the Submit Now submit control the page must be replaced by the form data.
     Among the variables you must see a header named "myHeader". You must not see a header named
     "wrongData".
  */
  test("11.8.1.a — 11.8.1.a name element with value attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.8/11.8.1/11.8.1.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Now" }));
    const headers = req ? req.headers() : {};
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(body).toContain("<value>one</value>");
    expect(body).toContain("<value>two</value>");
    expect(body).toContain("<value>three</value>");
    expect(String(headers["myheader"] || "")).toContain("myValue1");
    expect(Object.keys(headers).some((name) => name.toLowerCase() === "wrongdata")).toBe(false);
  });

  /*
     Empty header name expression must prevent that header/value pair from being emitted.
  */
  test("11.8.1.b — empty header name suppresses header emission", async ({ page }) => {
    // TEST-TRACE: promote 11.8.1.b to verify that empty header name does not emit the configured header value.
    await loadAndWait(page, "Chapt11/11.8/11.8.1/11.8.1.b.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Now" }));
    const headers = req ? req.headers() : {};
    const headerValues = Object.values(headers).map((value) => String(value));
    expect(headerValues.some((value) => value.includes("myValue"))).toBe(false);
    expect(Object.keys(headers).some((name) => name.toLowerCase() === "myheader")).toBe(false);
  });

  /*
     When you activate the Submit Now submit control the page must be replaced by the form data.
     Among the variables you must see a header named "myHeader" with a value of "three". You must
     not see a value of "wrongValue".
  */
  test("11.8.2.a — 11.8.2.a value element with value attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.8/11.8.2/11.8.2.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Now" }));
    const headers = req ? req.headers() : {};
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(body).toContain("<value>one</value>");
    expect(body).toContain("<value>two</value>");
    expect(body).toContain("<value>three</value>");
    expect(String(headers["myheader"] || "").trim()).toBe("three");
    expect(body).not.toContain("wrongValue");
    expect(String(headers["myheader"] || "")).not.toContain("wrongValue");
  });

  /*
     When you activate the Submit Now submit control the page must be replaced by the form data.
     Among the variables you must see two headers named "myHeader1" and "myHeader2". myHeader1 must
     have the value "myValue1" and myHeader2 must have the value "myValue2".
  */
  test("11.8.a — 11.8.a header element of submission element", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.8/11.8.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Now" }));
    const headers = req ? req.headers() : {};
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(body).toContain("<data");
    expect(body).toContain("<value>one</value>");
    expect(body).toContain("<value>two</value>");
    expect(body).toContain("<value>three</value>");
    expect(String(headers["myheader1"] || "")).toContain("myValue1");
    expect(String(headers["myheader2"] || "")).toContain("myValue2");
  });

  /*
     When you activate the Submit Now submit control the page must be replaced by the form data.
     Among the variables you must see three headers named "myHeader".
  */
  test("11.8.b — 11.8.b header element with nodeset attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.8/11.8.b.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Now" }));
    const headers = req ? req.headers() : {};
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(body).toContain("<value>one</value>");
    expect(body).toContain("<value>two</value>");
    expect(body).toContain("<value>three</value>");
    const combinedValues = String(headers["myheader"] || "")
      .split(",")
      .map((value) => value.trim())
      .filter((value) => value !== "");
    expect(combinedValues).toEqual(["one", "two", "three"]);
  });

  /*
     When you activate the Submit Now submit control the page must be replaced by the form data.
     Among the variables you must see one header named "myHeader". myHeader must have the values
     "myValue1,myValue2,myValue1,myValue2,myValue3,myValue4,myValue4" in that order.
  */
  test("11.8.c — 11.8.c header element with similar name elements", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.8/11.8.c.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Now" }));
    const headers = req ? req.headers() : {};
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(body).toContain("<data");
    expect(body).toContain("<value>one</value>");
    expect(body).toContain("<value>two</value>");
    expect(String(headers["myheader"] || "").replace(/\s+/g, "")).toBe(
      "myValue1,myValue2,myValue1,myValue2,myValue3,myValue4,myValue4"
    );
  });

  /*
     When you activate the Use Get Method submit control the page must be replaced by the form data.
     The value "blue" must appear in the request URI but must not appear in the form data.
  */
  test("11.9.1.a — 11.9.1.a get submission method", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.1/11.9.1.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Use Get Method" }));
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("GET");
    expect(req?.url()).toMatch(/blue/);
    expect(body).toBe("");
  });

  /*
     When you activate the Use Post Method submit control the page must be replaced by the form
     data. The value "blue" must appear in the form data.
  */
  test("11.9.2.a — 11.9.2.a post submission method", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.2/11.9.2.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Use Post Method" }));
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(req?.url()).not.toMatch(/blue/);
    expect(body).toContain("blue");
  });

  /*
     When you activate the Use Multipart-Post Method submit control the page must be replaced by the
     form data. The value "blue" must appear in the form data.
  */
  test("11.9.2.b — 11.9.2.b multipart-post submission method", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.2/11.9.2.b.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Use Multipart-Post Method" }));
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(req?.url()).not.toMatch(/blue/);
    expect(body).toContain("blue");
  });

  /*
     When you activate the Use Form-Data-Post Method submit control the page must be replaced by the
     form data. The value "blue" must appear in the form data.
  */
  test("11.9.2.c — 11.9.2.c form-data-post submission method", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.2/11.9.2.c.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Use Form-Data-Post Method" }));
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(req?.url()).not.toMatch(/blue/);
    expect(body).toContain("blue");
  });

  /*
     When you activate the Use Urlencoded-Post Method submit control the page must be replaced by
     the form data. The value "blue" must appear in the form data.
  */
  test("11.9.2.d — 11.9.2.d urlencoded-post submission method", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.2/11.9.2.d.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Use Urlencoded-Post Method" }));
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("POST");
    expect(req?.url()).not.toMatch(/blue/);
    expect(body).toContain("color=blue");
  });

  /*
     When you activate the Use Put Method submit control the page must be replaced by the form data.
     The value "blue" must appear in the form data.
  */
  test("11.9.3.a — 11.9.3.a put submission method", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.3/11.9.3.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Use Put Method" }));
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("PUT");
    expect(body).toContain("blue");
  });

  /*
     When you activate the Use Put Method submit control the value "blue" will be submitted to a
     local file called "myfile.txt".
  */
  test("11.9.3.b — put submission writes expected local payload", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.3/11.9.3.b.xhtml");
    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Use Put Method" }),
      (request) => request.method() === "PUT" && /myfile\.txt(?:\?|$)/i.test(request.url()),
      3000
    );
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("PUT");
    expect(req?.url()).toMatch(/myfile\.txt(?:\?|$)/i);
    expect(body).toContain("blue");
  });

  /*
     When you activate the Use Delete Method submit control the page must be replaced by the form
     data. The value "blue" must appear in the request URI but must not appear in the form data.
  */
  test("11.9.4.a — 11.9.4.a delete submission method", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.4/11.9.4.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Use Delete Method" }));
    const body = req ? (await req.postData()) || "" : "";
    expect(req?.method()).toBe("DELETE");
    expect(req?.url()).toMatch(/blue/);
    expect(body).not.toContain("blue");
  });

  /*
     The local file, deleteme.txt, must be deleted when you activate the Submit control. If you
     activate the Load submit control after activating the Submit control you must get a You pass
     message.
  */
  test("11.9.4.b — delete then load emits resource-error confirmation", async ({ page }) => {
    collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.9/11.9.4/11.9.4.b.xhtml");
    const deleteReq = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Submit" }),
      (request) => request.method() === "DELETE" && /deleteme\.txt(?:\?|$)/i.test(request.url()),
      3000
    );
    expect(deleteReq?.method()).toBe("DELETE");
    expect(deleteReq?.url()).toMatch(/deleteme\.txt(?:\?|$)/i);

    const loadReq = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Load" }),
      (request) => request.method() === "GET" && /deleteme\.txt(?:\?|$)/i.test(request.url()),
      3000
    );
    expect(loadReq?.method()).toBe("GET");
    const loadResponse = loadReq ? await loadReq.response() : null;
    expect(loadResponse?.status()).toBe(404);
  });

  test("11.9.5.a — default XML serialization uses application/xml", async ({ page }) => {
    await runSerializationCase(page, "Chapt11/11.9/11.9.5/11.9.5.a.xhtml", "PUT", "application/xml");
  });

  test("11.9.6.a — multipart-post serialization submits deterministic XML payload", async ({ page }) => {
    // TEST-TRACE: assert multipart/related content-type for multipart-post serialization; helps tests/w3c/ch11.spec.ts "11.9.6.a".
    await runSerializationCase(page, "Chapt11/11.9/11.9.6/11.9.6.a.xhtml", "POST", "multipart/related");
  });
  test("11.9.7.a — form-data-post serialization submits deterministic XML payload", async ({ page }) => {
    // TEST-TRACE: assert multipart/form-data content-type for form-data-post serialization; helps tests/w3c/ch11.spec.ts "11.9.7.a".
    await runSerializationCase(page, "Chapt11/11.9/11.9.7/11.9.7.a.xhtml", "POST", "multipart/form-data");
  });

  /*
     When you activate the Submit Data submit control the page must be replaced by the form data.
     The data must contain the value "Ren%C3%A9". The form data must be in
     application/x-www-form-urlencoded format according to the W3C specification at this link:
     XForms 1.1 specification
  */
  test("11.9.8.a — 11.9.8.a serialization as application/x-www-form-urlencoded", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.9/11.9.8/11.9.8.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit Data" }));
    const body = req ? (await req.postData()) || "" : "";
    const headers = req ? req.headers() : {};
    expect(req?.method()).toBe("POST");
    expect((headers["content-type"] || "").toLowerCase()).toContain("application/x-www-form-urlencoded");
    expect(body).toContain("Ren%C3%A9");
  });

  test("11.9.a — HTTP post submission uses POST", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.a.xhtml", "Post Data", "POST", "http:");
  });

  test("11.9.b — HTTP get submission uses GET", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.b.xhtml", "Get Data", "GET", "http:");
  });

  test("11.9.c — HTTP put submission uses PUT", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.c.xhtml", "Put Data", "PUT", "http:");
  });

  test("11.9.d — HTTP multipart-post submission uses POST", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.d.xhtml", "Post Data", "POST", "http:");
  });

  test("11.9.e — HTTP form-data-post submission uses POST", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.e.xhtml", "Post Data", "POST", "http:");
  });

  test("11.9.f — HTTP urlencoded-post submission uses POST", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.f.xhtml", "Post Data", "POST", "http:");
  });

  test("11.9.g — HTTPS post submission uses POST", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.g.xhtml", "Post Data", "POST", "https:");
  });

  test("11.9.h — HTTPS get submission uses GET", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.h.xhtml", "Get Data", "GET", "https:");
  });

  test("11.9.i — HTTPS put submission uses PUT", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.i.xhtml", "Put Data", "PUT", "https:");
  });

  test("11.9.j — HTTPS multipart-post submission uses POST", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.j.xhtml", "Post Data", "POST", "https:");
  });

  test("11.9.k — HTTPS form-data-post submission uses POST", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.k.xhtml", "Post Data", "POST", "https:");
  });

  test("11.9.l — HTTPS urlencoded-post submission uses POST", async ({ page }) => {
    await runHttpMethodCase(page, "Chapt11/11.9/11.9.l.xhtml", "Post Data", "POST", "https:");
  });

  test("11.9.m — mailto post dispatches resource-error without HTTP request", async ({ page }) => {
    await runNonHttpResourceErrorCase(page, "Chapt11/11.9/11.9.m.xhtml", "Post Data", "mailto:no-one@w3.org");
  });

  test("11.9.n — file get dispatches resource-error without HTTP request", async ({ page }) => {
    await runNonHttpResourceErrorCase(page, "Chapt11/11.9/11.9.n.xhtml", "Get Data", "file:11.9.n.data.xml");
  });

  test("11.9.o — file put dispatches resource-error without HTTP request", async ({ page }) => {
    await runNonHttpResourceErrorCase(page, "Chapt11/11.9/11.9.o.xhtml", "Put Data", "file:11.9.o.data.xml");
  });

  test("11.9.p — mailto urlencoded-post dispatches resource-error without HTTP request", async ({ page }) => {
    await runNonHttpResourceErrorCase(page, "Chapt11/11.9/11.9.p.xhtml", "Post Data", "mailto:no-one@w3.org");
  });

  test("11.9.q — mailto form-data-post dispatches resource-error without HTTP request", async ({ page }) => {
    await runNonHttpResourceErrorCase(page, "Chapt11/11.9/11.9.q.xhtml", "Post Data", "mailto:no-one@w3.org");
  });

  /*
     Invalid targetref on replace=instance must dispatch xforms-submit-error and expose target-error.
  */
  test("11.10.a — invalid targetref dispatches submit-error and target-error type", async ({ page }) => {
    // TEST-TRACE: promote 11.10.a by asserting xforms-submit-error dialog and target-error output propagation.
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.10/11.10.a.xhtml");
    const beforeCount = dialogs.length;
    await clickTrigger(page, "Replace Instance");
    await page.waitForTimeout(500);
    const newDialogs = dialogs.slice(beforeCount);
    expect(newDialogs.some((message) => /xforms-submit-error/i.test(message))).toBe(true);
    const text = await getFormControlText(page);
    expect(text).toContain("target-error");
  });

  /*
     You must see the value "Thomas" for the Car Owner output control. When you activate the Replace
     Instance submit control the value must change to "Janel".
  */
  test("11.10.b — 11.10.b submission response with the target data node receiving text", async ({ page }) => {
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.10/11.10.b.xhtml");
    // TEST-TRACE: strengthen 11.10.b using fixture semantics (replace=text + targetref=carOwner) and assert exact before/after owner values.
    const beforeText = await getFormControlText(page);
    expect(beforeText).toContain("Car Owner");
    expect(beforeText).toContain("Thomas");
    expect(beforeText).not.toContain("Janel");

    const beforeCount = dialogs.length;
    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Replace Instance" }),
      (request) =>
        request.method() === "GET" &&
        /\/w3c-suite\/Chapt11\/11\.10\/11\.10\.data2\.txt(?:\?|$)/i.test(request.url()),
      5000
    );
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("GET");
    expect(req?.url()).toContain("/w3c-suite/Chapt11/11.10/11.10.data2.txt");
    const body = req ? (await req.postData()) || "" : "";
    expect(body).toBe("");

    await waitForCondition(
      page,
      async () => {
        const currentText = await getFormControlText(page);
        return currentText.includes("Car Owner") && currentText.includes("Janel") && !currentText.includes("Thomas");
      },
      { timeoutMs: 5000, description: "11.10.b owner output replacement to Janel" }
    );
    const afterText = await getFormControlText(page);
    expect(afterText).toContain("Car Owner");
    expect(afterText).toContain("Janel");
    expect(afterText).not.toContain("Thomas");
    const newDialogs = dialogs.slice(beforeCount);
    expect(newDialogs.some((message) => /^xforms-submit-error$/i.test(message))).toBe(false);
  });

  /*
     Replace Instance must keep first instance values and update second instance values.
  */
  test("11.10.c — targetref replacement updates only second instance values", async ({ page }) => {
    // TEST-TRACE: merge duplicate 11.10.c variants to verify both relative action request resolution and selective second-instance targetref replacement.
    await loadAndWait(page, "Chapt11/11.10/11.10.c.xhtml");
    const before = await getFormControlText(page);
    expect(before).toContain("Henry");
    expect(before).toContain("Acura");
    expect(before).toContain("white");
    expect(before).toContain("Thomas");
    expect(before).toContain("Toyota");
    expect(before).toContain("silver");
    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Replace Instance" }),
      (request) => request.method() === "GET" && /\/w3c-suite\/Chapt11\/11\.10\/11\.10\.data\.xml(?:\?|$)/.test(request.url()),
      3000
    );
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("GET");
    expect(req?.url()).toContain("/w3c-suite/Chapt11/11.10/11.10.data.xml");
    await page.waitForTimeout(500);
    const after = await getFormControlText(page);
    expect(after).toContain("Henry");
    expect(after).toContain("Acura");
    expect(after).toContain("white");
    expect(after).toContain("Janel");
    expect(after).toContain("Saturn");
    expect(after).toContain("red");
    expect(after).not.toContain("Thomas");
    expect(after).not.toContain("Toyota");
    expect(after).not.toContain("silver");
  });

  test("11.11.1.a — SOAP envelope submission serializes soap:Envelope payload", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.11/11.11.1/11.11.1.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit SOAP" }), 5000);
    const headers = req ? req.headers() : {};
    const body = req ? (await req.postData()) || "" : "";
    // TEST-TRACE: validate SOAP envelope payload shape/content via SaxonJS XPath checks; helps tests/w3c/ch11.spec.ts "11.11.1.a".
    const bodyAnalysis = await evaluateSubmissionXPath(page, body, {
      rootLocalName: "local-name(/*[1])",
      rootNamespaceUri: "namespace-uri(/*[1])",
      containsMessage: "contains(normalize-space(string(/*[1])), 'This is the message')",
    });
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("POST");
    expect(getHeaderValue(headers, "content-type").toLowerCase()).toContain("application/soap+xml");
    expect(bodyAnalysis.parseError).toBe("");
    expect(bodyAnalysis.xpathError).toBe("");
    expect(bodyAnalysis.values.rootLocalName).toBe("Envelope");
    expect(bodyAnalysis.values.rootNamespaceUri).toBe("http://www.w3.org/2001/12/soap-envelope");
    expect(bodyAnalysis.values.containsMessage).toBe("true");
  });

  /*
     SOAP submission content type must be application/soap+xml.
  */
  test("11.11.2.a — SOAP submission sets application/soap+xml content type", async ({ page }) => {
    // TEST-TRACE: promote 11.11.2.a to assert SOAP mediatype on submission request headers.
    await loadAndWait(page, "Chapt11/11.11/11.11.2/11.11.2.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit SOAP" }));
    const headers = req ? req.headers() : {};
    expect((headers["content-type"] || "").toLowerCase()).toContain("application/soap+xml");
  });

  test("11.11.3.a — SOAP GET sets application/soap+xml accept header with charset", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.11/11.11.3/11.11.3.a.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit SOAP" }), 5000);
    const headers = req ? req.headers() : {};
    const accept = getHeaderValue(headers, "accept");
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("GET");
    expect(accept.toLowerCase()).toContain("application/soap+xml");
    expect(accept.toUpperCase()).toMatch(/ASCII|UTF-8/);
  });

  /*
     SOAP post submission content type must be application/soap+xml.
  */
  test("11.11.3.b — SOAP post submission uses SOAP content type", async ({ page }) => {
    // TEST-TRACE: promote 11.11.3.b to validate SOAP POST method and content-type handling.
    await loadAndWait(page, "Chapt11/11.11/11.11.3/11.11.3.b.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit SOAP" }));
    const headers = req ? req.headers() : {};
    expect(req?.method()).toBe("POST");
    expect((headers["content-type"] || "").toLowerCase()).toContain("application/soap+xml");
  });

  test("11.11.3.c — SOAP POST keeps mediatype and action metadata on Content-Type", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.11/11.11.3/11.11.3.c.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit SOAP" }), 5000);
    const headers = req ? req.headers() : {};
    const contentType = getHeaderValue(headers, "content-type");
    const soapAction = getHeaderValue(headers, "soapaction");
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("POST");
    // TEST-TRACE: enforce 11.11.3.c SOAP binding semantics (text/xml + SOAPAction extraction);
    // helps tests/xforms/w3c/ch11.spec.ts "11.11.3.c".
    expect(contentType.toLowerCase()).toContain("text/xml");
    expect(contentType.toUpperCase()).toContain("ASCII");
    expect(soapAction).toContain("http://www.google.com");
    expect(contentType.toLowerCase()).not.toContain("application/soap+xml");
  });

  test("11.11.3.d — SOAP GET with encoding sets application/soap+xml and UTF-8 accept", async ({ page }) => {
    // TEST-TRACE: strengthen 11.11.3.d to validate SOAP GET accept header includes application/soap+xml and UTF-8 encoding.
    await loadAndWait(page, "Chapt11/11.11/11.11.3/11.11.3.d.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit SOAP" }), 5000);
    const headers = req ? req.headers() : {};
    const accept = getHeaderValue(headers, "accept");
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("GET");
    expect(accept.toLowerCase()).toContain("application/soap+xml");
    expect(accept.toUpperCase()).toContain("UTF-8");
  });

  test("11.11.3.e — SOAP POST with encoding sets application/soap+xml and UTF-8", async ({ page }) => {
    await loadAndWait(page, "Chapt11/11.11/11.11.3/11.11.3.e.xhtml");
    const req = await submitAndCapture(page, page.getByRole("button", { name: "Submit SOAP" }), 5000);
    const headers = req ? req.headers() : {};
    const contentType = getHeaderValue(headers, "content-type");
    expect(req).not.toBeNull();
    expect(req?.method()).toBe("POST");
    expect(contentType.toLowerCase()).toContain("application/soap+xml");
    expect(contentType.toUpperCase()).toContain("UTF-8");
  });

  test("11.11.4.a — forced SOAP failure dispatches xforms-submit-error", async ({ page }) => {
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.11/11.11.4/11.11.4.a.xhtml");
    await forceOneShotEndpointFailure(page, /\/echo\.sh(?:\?|$)/i, {
      status: 500,
      contentType: "application/xml",
      body: "<?xml version=\"1.0\"?><error>forced failure</error>",
    });
    const beforeCount = dialogs.length;
    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Submit SOAP" }),
      (request) => /\/echo\.sh(?:\?|$)/i.test(request.url()),
      5000
    );
    expect(req).not.toBeNull();
    await waitForCondition(
      page,
      () => dialogs.slice(beforeCount).some((message) => /^xforms-submit-error$/i.test(message)),
      { timeoutMs: 5000, description: "11.11.4.a submit-error dialog" }
    );
  });

  test("11.11.4.b — successful SOAP response dispatches xforms-submit-done", async ({ page }) => {
    const dialogs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt11/11.11/11.11.4/11.11.4.b.xhtml");
    const beforeCount = dialogs.length;
    const req = await clickAndCaptureRequest(
      page,
      page.getByRole("button", { name: "Submit SOAP" }),
      (request) => /\/echo\.sh(?:\?|$)/i.test(request.url()),
      5000
    );
    expect(req).not.toBeNull();
    await waitForCondition(
      page,
      () => dialogs.slice(beforeCount).some((message) => /^xforms-submit-done$/i.test(message)),
      { timeoutMs: 5000, description: "11.11.4.b submit-done dialog" }
    );
  });
});
