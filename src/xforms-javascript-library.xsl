<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    version="3.0">
    
    <xsl:variable name="saxon-forms-javascript" as="xs:string*">
        var XFormsDoc = null;
        var XForm = null;
        var defaultInstance = null;
        var defaultInstanceID = null;
        
        var models = {}
        var instances = {};
        var modelDefaultInstanceKeyMap = {};
        var bindings = [];
        var actions = {};
        var eventActions = {};
        var currentEventContextStack = [];
        var submitSerializeBodyOverride = null;
        var dispatchedEvents = [];
        var switches = {}; // map switch ID to array of case IDs
        var switchSelections = {};
        var caseSwitches = {}; // map case ID to ID of parent switch
        var cases = {}; 
        var submissions = {};
        var submissionsInProgress = {};
        var outputs = {};
        var repeats = {};
        var repeatModelContexts = {};
        var repeatContextNodesets = {};       
/* PERF-6a: map repeat ID → resolved instance ID for dirty-instance guard */
        var repeatInstanceIds = {};
        /* TEST-TRACE: PERF-6a multi-instance deps per repeat; helps tests/supplemental/engine-limitations.spec.ts "#5 mode change refreshes filtered repeat". */
        var repeatInstanceDeps = {};
        /* PERF-6b: map repeat ID → resolved nodeset (e.g. "instance('target')/o:control") */
        var repeatRefs = {};
        /* PERF-6b: queue of pending structural mutations for splice-based refresh */
        var pendingMutations = [];
        
        var repeatIndexMap = {};
        var repeatSizeMap = {};
        var elementsUsingIndexFunction = {};
        var elementsContextUsingIndexFunction = {};
        
        var deferredUpdateFlags = {};
        /* PERF-6a: track which instance IDs were mutated so refreshRepeats-JS
           can skip repeats bound to unaffected instances. */
        var dirtyInstances = {};
        /* TEST-TRACE: persist validity/required MIP state between revalidate and refresh;
           helps tests/supplemental/saxon-forms-validation.spec.ts. */
        var validationMIPs = {};
        var visitedControls = {};
        var forceFullValidationFeedback = false;
                
        var getCurrentDate = function(){
            var today = new Date();
            var dd = today.getDate();
            var mm = today.getMonth() + 1; //January is 0!
            var yyyy = today.getFullYear();
                
            if(dd &lt; 10) { dd = '0' + dd; }                 
            if(mm &lt; 10) { mm = '0' + mm; } 
                
            today = yyyy + '-' + mm + '-' + dd;
            return today;
        }
        
        var reset = function() {
            models = {}
            instances = {};
            modelDefaultInstanceKeyMap = {};
            bindings = [];
            actions = {};
            eventActions = {};
            currentEventContextStack = [];
            submitSerializeBodyOverride = null;
            dispatchedEvents = [];
            switches = {}; // map switch ID to array of case IDs
            switchSelections = {};
            caseSwitches = {}; // map case ID to ID of parent switch
            cases = {}; 
            submissions = {};
            submissionsInProgress = {};
            outputs = {};
            repeats = {};
            repeatModelContexts = {};
            repeatContextNodesets = {};       
repeatInstanceIds = {};
            repeatInstanceDeps = {};
            repeatRefs = {};
            pendingMutations = [];
        
            repeatIndexMap = {};
            repeatSizeMap = {};
            elementsUsingIndexFunction = {};
            elementsContextUsingIndexFunction = {};
            dirtyInstances = {};
            validationMIPs = {};
            visitedControls = {};
            forceFullValidationFeedback = false;
            /* TEST-TRACE: preserve initial snapshots across reset */
        }
        
        /* TEST-TRACE: snapshot initial instance data for xf:reset;
           helps tests/w3c/ch10.spec.ts "10.a", "10.13.b" */
        var initialInstances = {};
        var saveInitialInstance = function(name, value) {
            initialInstances[name] = value.cloneNode(true);
        }
        var getInitialInstance = function(name) {
            return initialInstances[name] ? initialInstances[name].cloneNode(true) : null;
        }
        var restoreInitialInstances = function() {
            for (var key in initialInstances) {
                instances[key] = initialInstances[key].cloneNode(true);
            }
        }
        
        var setModel = function(name, value) {
            models[name] = value;
        }
        var getModel = function(name) {
            return models[name];
        }
        
        var setModelDefaultInstanceKey = function(modelId, instanceId) {
            modelDefaultInstanceKeyMap[modelId] = [instanceId];
        }
        var getModelDefaultInstanceKey = function(modelId) {
            return modelDefaultInstanceKeyMap[modelId];
        }
                
        var setBinding = function(value) {
            bindings.push(value);
        } 
        var getBindings = function() {
            return bindings;
        }


        var setXFormsDoc = function(doc) {
            XFormsDoc = doc;
        }
                
        var getXFormsDoc = function() {
            return XFormsDoc;
        }
                
        var setXForm = function(element) {
            XForm = element;
        }
                
        var getXForm = function() {
            return XForm;
        }
                
                
        var setInstance = function(name, value) {
            instances[name] = value;
        } 
                
        var getInstance = function(name) {
            return instances[name];
        }
        
        var setDefaultInstance = function(doc) {
            defaultInstance = doc;
        }
                
        var getDefaultInstance = function() {
            return defaultInstance;
        }
                
        var setDefaultInstanceId = function(id) {
            defaultInstanceId = id;
        }
                
        var getDefaultInstanceId = function() {
            return defaultInstanceId;
        }
                
                
        var getInstanceKeys = function() {
            return Object.keys(instances);
        }
         
         // !! return value does not match required data type map(xs:string, element())
        var getInstances = function() {
            return instances;
        }
                
        var setDeferredUpdateFlag = function(name) {
            deferredUpdateFlags[name] = 'true';
        } 
        var setDeferredUpdateFlags = function(names) {
            names.forEach(setDeferredUpdateFlag);
        } 
                
        var clearDeferredUpdateFlag = function(name) {
            deferredUpdateFlags[name] = null; 
        }
        var clearDeferredUpdateFlags = function() {
            Object.keys(deferredUpdateFlags).forEach(clearDeferredUpdateFlag); 
        }
        /* PERF-6a: dirty-instance helpers */
        var addDirtyInstance = function(id) {
            dirtyInstances[id] = true;
        }
        var isDirtyInstance = function(id) {
            return dirtyInstances[id] === true;
        }
        var hasDirtyInstances = function() {
            return Object.keys(dirtyInstances).length > 0;
        }
        var clearDirtyInstances = function() {
            dirtyInstances = {};
        }
        /* TEST-TRACE: validation MIP registry helpers for refresh-time CSS class projection;
           helps tests/supplemental/saxon-forms-validation.spec.ts. */
        var _validationMipKey = function(instanceId, ref) {
            return String(instanceId || '') + '|' + String(ref || '');
        }
        var setValidationMIP = function(instanceId, ref, valid, required) {
            var key = _validationMipKey(instanceId, ref);
            validationMIPs[key] = {
                valid: String(valid) === 'true',
                required: String(required) === 'true'
            };
            return true;
        }
        var getValidationMIPValid = function(instanceId, ref) {
            var key = _validationMipKey(instanceId, ref);
            if (!(key in validationMIPs)) return '';
            return validationMIPs[key].valid ? 'true' : 'false';
        }
        var getValidationMIPRequired = function(instanceId, ref) {
            var key = _validationMipKey(instanceId, ref);
            if (!(key in validationMIPs)) return '';
            return validationMIPs[key].required ? 'true' : 'false';
        }
        var clearValidationMIPs = function() {
            validationMIPs = {};
            return true;
        }
        var markControlVisited = function(instanceId, ref) {
            var key = _validationMipKey(instanceId, ref);
            visitedControls[key] = true;
            return true;
        }
        var isControlVisited = function(instanceId, ref) {
            var key = _validationMipKey(instanceId, ref);
            return visitedControls[key] === true;
        }
        var clearVisitedControls = function() {
            visitedControls = {};
            return true;
        }
        var setForceFullValidationFeedback = function(value) {
            forceFullValidationFeedback = (value === true || String(value) === 'true');
            return true;
        }
        var isForceFullValidationFeedback = function() {
            return forceFullValidationFeedback === true;
        }
        var clearForceFullValidationFeedback = function() {
            forceFullValidationFeedback = false;
            return true;
        }
                
        var getDeferredUpdateFlag = function(name) {
            return deferredUpdateFlags[name];
        }
        var getDeferredUpdateFlags = function() {
            return deferredUpdateFlags;
        }
                
                
        var addAction = function(name, value){
            actions[name] = value;
        }
                
        var getAction = function(name){
            return actions[name];
        }
        
        var addEventAction = function(name, value){
            eventActions[name] = value;
            //console.log('[xforms-javascript-library] Adding action for event ' + name);
        }
        
        var getEventAction = function(name){
            return eventActions[name];
        }
        var recordDispatchedEvent = function(name, context){
            var eventRecord = {
                name: String(name || ''),
                context: {}
            };
            if (context) {
                var extract = function(key) {
                    var value = null;
                    if (context &amp;&amp; typeof context.get === 'function') {
                        value = context.get(key);
                    } else if (context &amp;&amp; typeof context === 'object') {
                        value = context[key];
                    }
                    if (value !== null &amp;&amp; value !== undefined) {
                        eventRecord.context[key] = String(value);
                    }
                };
                ['targetid', 'error-type', 'resource-uri', 'response-status-code', 'response-reason-phrase'].forEach(extract);
            }
            dispatchedEvents.push(eventRecord);
            if (dispatchedEvents.length &gt; 200) {
                dispatchedEvents.shift();
            }
            return true;
        }
        var getDispatchedEvents = function(){
            return dispatchedEvents.slice();
        }
        var clearDispatchedEvents = function(){
            dispatchedEvents = [];
            return true;
        }
        var pushCurrentEventContext = function(context){
            currentEventContextStack.push(context || {});
            return true;
        }
        
        var popCurrentEventContext = function(){
            if (currentEventContextStack.length > 0) {
                currentEventContextStack.pop();
            }
            return true;
        }
        
        var getCurrentEventContext = function(){
            if (currentEventContextStack.length > 0) {
                return currentEventContextStack[currentEventContextStack.length - 1];
            }
            return null;
        }
        
        var getCurrentEventProperty = function(name){
            var ctx = getCurrentEventContext();
            if (!ctx) {
                return null;
            }
            if (typeof ctx.get === 'function') {
                return ctx.get(name);
            }
            return ctx[name];
        }
        var setCurrentEventProperty = function(name, value){
            var ctx = getCurrentEventContext();
            if (!ctx) {
                return null;
            }
            if (typeof ctx.set === 'function') {
                ctx = ctx.set(name, value);
                currentEventContextStack[currentEventContextStack.length - 1] = ctx;
            } else {
                ctx[name] = value;
            }
            return value;
        }
        var setSubmitSerializeBodyOverride = function(value){
            submitSerializeBodyOverride = value;
            return value;
        }
        var getSubmitSerializeBodyOverride = function(){
            return submitSerializeBodyOverride;
        }
        var clearSubmitSerializeBodyOverride = function(){
            submitSerializeBodyOverride = null;
            return true;
        }
        
                
        var updateAction = function(actioni, key, value){
            actioni[key] = value;
            return actioni;
        }
        
        var addSwitch = function(name, value){
            switches[name] = value;
        }
        
        var getSwitch = function(name){
            return switches[name];
        }
        
        var setSwitchSelection = function(name, value){
            switchSelections[name] = value;
        }
        
        var getSwitchSelection = function(name){
            return switchSelections[name];
        }
        
        var setCaseSwitch = function(name, value){
            caseSwitches[name] = value;
        }
        
        var getCaseSwitch = function(name){
            return caseSwitches[name];
        }
        
        var setCaseStatus = function(name, value){
            cases[name] = value;
        }
        
        var getCaseStatus = function(name){
            return cases[name];
        }
        
        var selectCase = function(name){
            cases[name] = 'true';
        }
        var deselectCase = function(name){
            cases[name] = 'false';
        }
        
        
                
        var addSubmission = function(name, value){
            submissions[name] = value;
        }
                
        var getSubmission = function(name){
            return submissions[name];
        }
        var setSubmissionInProgress = function(name, value){
            submissionsInProgress[name] = (value === true);
        }
        var clearSubmissionInProgress = function(name){
            delete submissionsInProgress[name];
        }
        var isSubmissionInProgress = function(name){
            return submissionsInProgress[name] === true;
        }
                
        var addOutput = function(name, value){
            outputs[name] = value;
        }
                
        var getOutput = function(name){
            return outputs[name];
        }
        
        var removeOutput = function(name){
            if (name in outputs) {
                delete outputs[name];
            }
        }
                
        var getOutputKeys = function() {
            return Object.keys(outputs);
        }
                
        // repeats is a map of HTML IDs to xf:repeat elements
        var addRepeat = function(name, value){
            repeats[name] = value;
        }
        var addRepeatModelContext = function(name, value) {
            repeatModelContexts[name] = value;
        }
        var addRepeatContext = function(name, value) {
            repeatContextNodesets[name] = value;
        }
                
        var getRepeat = function(name){
            return repeats[name];
        }
        var getRepeatModelContext = function(name){
            return repeatModelContexts[name];
        }
        var getRepeatContext = function(name){
            return repeatContextNodesets[name];
        }
/* PERF-6a: store/retrieve the resolved instance ID for each repeat */
        var setRepeatInstanceId = function(name, value) {
            repeatInstanceIds[name] = value;
        }
        var getRepeatInstanceId = function(name) {
            return repeatInstanceIds[name] || "";
        }
        /* TEST-TRACE: extract instance('id') tokens from repeat nodeset for multi-dep dirty checks;
           helps tests/supplemental/engine-limitations.spec.ts "#5 mode change refreshes filtered repeat". */
        var setRepeatInstanceDeps = function(name, nodesetExpr) {
            var deps = [];
            var seen = {};
            var primary = repeatInstanceIds[name] || "";
            if (primary) {
                deps.push(primary);
                seen[primary] = true;
            }
            var src = String(nodesetExpr || "");
var re = /instance\s*\(\s*['\x22]([^'\x22]+)['\x22]\s*\)/g;
            var m;
            while ((m = re.exec(src)) !== null) {
                var id = m[1];
if (id &amp;&amp; !seen[id]) {
                    deps.push(id);
                    seen[id] = true;
                }
            }
            repeatInstanceDeps[name] = deps;
        }
        var getRepeatInstanceDeps = function(name) {
            if (repeatInstanceDeps[name] &amp;&amp; repeatInstanceDeps[name].length) {
                return repeatInstanceDeps[name];
            }
            var primary = getRepeatInstanceId(name);
            return primary ? [primary] : [];
        }
var isDirtyRepeat = function(name) {
            var deps = getRepeatInstanceDeps(name);
            for (var i = 0; i &lt; deps.length; i++) {
                if (isDirtyInstance(deps[i])) {
                    return true;
                }
            }
            return false;
        }
        /* PERF-6b: store/retrieve the repeat's own resolved nodeset */
        var setRepeatRef = function(name, value) {
            repeatRefs[name] = value;
        }
        var getRepeatRef = function(name) {
            return repeatRefs[name] || "";
        }
        /* PERF-6b: pending structural mutation tracking */
        var addPendingMutation = function(type, instanceId, newPosition) {
            pendingMutations.push({type: type, instanceId: instanceId, position: newPosition});
        }
        var getPendingAppendForInstance = function(instanceId) {
            for (var i = 0; i &lt; pendingMutations.length; i++) {
                if (pendingMutations[i].instanceId === instanceId &amp;&amp; pendingMutations[i].type === "append") {
                    return pendingMutations[i].position;
                }
            }
            return 0;
        }
        var hasPendingMutations = function() {
            return pendingMutations.length > 0;
        }
        var clearPendingMutations = function() {
            pendingMutations = [];
        }
        
        var getRepeatKeys = function() {
            return Object.keys(repeats);
        }
                
                                
        var getRepeatIndexMap = function() {
            return repeatIndexMap;
        }
                
        var setRepeatIndex = function(name, value) {
            repeatIndexMap[name] = value;
        }
                
        var getRepeatIndex = function(name) {
            if ( typeof(repeatIndexMap[name]) != 'undefined' ) {
                return repeatIndexMap[name];
            }
            else {
                return 0;
            }
        }
        
        /* TEST-TRACE: check if a repeat ID has been registered;
           helps tests/w3c/ch07.spec.ts "7.7.5.b" */
        var isRepeatRegistered = function(name) {
            return typeof(repeatIndexMap[name]) != 'undefined';
        } 
                
        var setRepeatSize = function(name, value) {
            repeatSizeMap[name] = value;
        }
                
        var getRepeatSize = function(name) {
            if ( typeof(repeatSizeMap[name]) != 'undefined' ) {
                return repeatSizeMap[name];
            }
            else {
                return 0;
            }
        } 
                
        var setElementUsingIndexFunction = function(name, value) {
            elementsUsingIndexFunction[name] = value;
        } 
                
        var getElementUsingIndexFunction = function(name) {
            return elementsUsingIndexFunction[name];
        }
                
        var getElementsUsingIndexFunctionKeys = function() {
            return Object.keys(elementsUsingIndexFunction);
        }

        var setElementContextUsingIndexFunction = function(name, value) {
            elementsContextUsingIndexFunction[name] = value;
        } 

        var getElementContextUsingIndexFunction = function(name) {
            return elementsContextUsingIndexFunction[name];
        }

                
        var startTime = function(name) {
            console.time(name);
        }
                
        var endTime = function(name) {
            console.timeEnd(name);
        }
                
        var highlightClicked = function(id) {
            var item = document.getElementById(id);
            toggleClass(item);
        }
                
        var toggleClass = function(element) {
            if (element.className == 'selected') {
                element.classList.remove('selected');
            }
            else {
                var x = document.getElementsByClassName('selected');
                var i;
                for (i = 0; i &lt; x.length; i++) {
                    x[i].classList.remove('selected');
                } 
                element.classList.add('selected');
             }
         }
                
         /* TEST-TRACE: enhanced setFocus with suffixed-ID fallback and group-to-child focus;
            helps tests/w3c/ch09.spec.ts "9.1.1.c", tests/w3c/ch10.spec.ts "10.7.a" */
         var setFocus = function(id) {
            var item = document.getElementById(id);
            /* fallback: rendered IDs have position suffix (e.g. "shipping-0") */
            if (!item) {
                item = document.querySelector('[id^="' + id + '-"]');
            }
            if (!item) return;
            /* if target is a group/div, focus the first focusable child */
            var focusable = item;
            if (item.tagName !== 'INPUT' &amp;&amp; item.tagName !== 'TEXTAREA' &amp;&amp; item.tagName !== 'SELECT') {
                var child = item.querySelector('input, textarea, select, [tabindex]');
                if (child) focusable = child;
            }
            focusable.focus();
         }
         
         var isActiveElement = function(id) {
            var active = document.activeElement;
            return !!(active &amp;&amp; active.id === id);
         }
         
         var setValue = function(id,val) {
             var item = document.getElementById(id);
             item.value = val;
         }
         
         var setCheckboxValue = function(id,val) {
            var item = document.getElementById(id);
            if (val == 'true') {
                item.checked = true;
            }
            else {
                item.checked = false;
            }
         }
         
         var setSrc = function(id,val) {
            var item = document.getElementById(id);
            item.src = val;
         }
         
         var debugAlert = function(message) {
            alert(message);
         }

         /**
          * Read a File object as XML, parse it, and replace the named
          * XForms instance with the parsed document element.
          * Triggers deferred updates (rebuild, recalculate, revalidate, refresh).
          *
          * Called from XSLT via: ixsl:call(ixsl:window(), 'readFileAsXML', [$file, $instanceId])
          */
         var readFileAsXML = function(file, instanceId) {
            var reader = new FileReader();
            reader.onload = function(e) {
                try {
                    var parser = new DOMParser();
                    var doc = parser.parseFromString(e.target.result, 'application/xml');
                    var parseError = doc.querySelector('parsererror');
                    if (parseError) {
                        alert('Invalid XML file: ' + parseError.textContent);
                        return;
                    }
                    setInstance(instanceId, doc.documentElement);
                    setDeferredUpdateFlags(['rebuild','recalculate','revalidate','refresh']);
                    // Trigger refresh by clicking the hidden refresh trigger
                    // (bridges async JS back into XSLT processing pipeline)
                    var refreshBtn = document.querySelector('button[data-action*="upload-refresh-trigger"]');
                    if (refreshBtn) { refreshBtn.click(); }
                } catch(err) {
                    alert('Error processing file: ' + err.message);
                }
            };
            reader.onerror = function() { alert('File read error'); };
            reader.readAsText(file);
         }

         /**
          * Open a file picker, read an XML file, parse it, and replace
          * the named XForms instance. Returns a Promise that resolves
          * to the root element name of the uploaded document (or rejects
          * on cancel/error).
          *
          * Called from XSLT via: ixsl:call(ixsl:window(), 'uploadAndSetInstance', [instanceId])
          */
         var uploadAndSetInstance = function(instanceId) {
            return new Promise(function(resolve, reject) {
                var input = document.createElement('input');
                input.type = 'file';
                input.accept = '.xml';
                input.onchange = function() {
                    if (!input.files || !input.files[0]) {
                        reject('No file selected');
                        return;
                    }
                    var file = input.files[0];
                    var reader = new FileReader();
                    reader.onload = function(e) {
                        try {
                            var parser = new DOMParser();
                            var doc = parser.parseFromString(e.target.result, 'application/xml');
                            var parseError = doc.querySelector('parsererror');
                            if (parseError) {
                                reject('XML parse error: ' + parseError.textContent);
                                return;
                            }
                            // Store as instance via Saxon-Forms JS API
                            setInstance(instanceId, doc.documentElement);
                            // Set deferred update flags so Saxon-Forms refreshes
                            setDeferredUpdateFlags(['rebuild','recalculate','revalidate','refresh']);
                            resolve(doc.documentElement.localName);
                        } catch(err) {
                            reject('Error processing file: ' + err.message);
                        }
                    };
                    reader.onerror = function() { reject('File read error'); };
                    reader.readAsText(file);
                };
                input.click();
            });
         }
         
        /* TEST-TRACE: crypto bridge for digest()/hmac(); uses @noble/hashes if loaded;
           returns empty string when library is unavailable;
           helps tests/w3c/ch07.spec.ts "7.8.3.*", "7.8.4.*" */
        var _nobleAlgMap = {
            'MD5': 'md5', 'SHA-1': 'sha1', 'SHA-256': 'sha256',
            'SHA-384': 'sha384', 'SHA-512': 'sha512'
        };
        var _toBytes = function(s) { return new TextEncoder().encode(s); };
        
        var computeDigest = function(data, algorithm, encoding) {
            if (typeof nobleHashes === 'undefined') return '';
            var algKey = _nobleAlgMap[algorithm];
            if (!algKey) return '';
            var hashFn = nobleHashes[algKey];
            if (!hashFn) return '';
            var hashBytes = hashFn(_toBytes(data));
            if (!encoding || encoding === 'base64') {
                return btoa(String.fromCharCode.apply(null, hashBytes));
            }
            return nobleHashes.bytesToHex(hashBytes);
        };
        
        var computeHmac = function(key, data, algorithm, encoding) {
            if (typeof nobleHashes === 'undefined' || !nobleHashes.hmac) return '';
            var algKey = _nobleAlgMap[algorithm];
            if (!algKey) return '';
            var hashFn = nobleHashes[algKey];
            if (!hashFn) return '';
            var macBytes = nobleHashes.hmac(hashFn, _toBytes(key), _toBytes(data));
            if (!encoding || encoding === 'base64') {
                return btoa(String.fromCharCode.apply(null, macBytes));
            }
            return nobleHashes.bytesToHex(macBytes);
        };
        <xsl:value-of select="$saxon-forms-web-components-javascript"/>
         
    </xsl:variable>
</xsl:stylesheet>