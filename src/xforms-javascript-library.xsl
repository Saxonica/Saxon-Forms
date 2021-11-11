<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    version="3.0">
    
    <xsl:variable name="saxon-forms-javascript" as="xs:string">
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
        var submissions = {};
        var outputs = {};
        var repeats = {};
        var repeatModelContexts = {};
        var repeatContextNodesets = {};       
        
        var repeatIndexMap = {};
        var repeatSizeMap = {};
        var elementsUsingIndexFunction = {};
                
        var deferredUpdateFlags = {};
                
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
        
        var setModel = function(name, value) {
            models[name] = value;
        }
        var getModel = function(name) {
            return models[name];
        }
        
        
        var setModelInstances = function(name, value) {
            modelInstanceMap[name] = value;
        } 
        var setModelInstance = function(modelId, instanceId, value) {
                    
            if (modelId in modelInstanceMap) {
                var modelInstances = modelInstanceMap[modelId];
                modelInstances[instanceId] = value;
            }
            else {
                instanceMap = {};
                instanceMap[instanceId] = value;
                modelInstanceMap[modelId] = instanceMap;
            }
        } 
        
        var setModelDefaultInstance = function(modelId, value) {
            modelDefaultInstanceMap[modelId] = value;
        }
        
        var setModelDefaultInstanceKey = function(modelId, instanceId) {
            modelDefaultInstanceKeyMap[modelId] = [instanceId];
        }
        var getModelDefaultInstanceKey = function(modelId) {
            return modelDefaultInstanceKeyMap[modelId];
        }
        
        var getModelInstances = function(modelId) {
            return modelInstanceMap[modelId];
        } 
        var getModelInstance = function(modelId, instanceId) {
            var modelInstances = modelInstanceMap[modelId];
            return modelInstances[instanceId];
        }
                
        var setModelInstanceKey = function(modelId, instanceId) {
            if (modelId in modelInstanceKeyMap) {
                var modelInstanceKeys = modelInstanceKeyMap[modelId];
                modelInstanceKeys.push(instanceId);
            }
            else {
                modelInstanceKeyMap[modelId] = [instanceId];
            }
        }
                
        var getModelInstanceKeys = function(modelId) {
            return modelInstanceKeyMap[modelId];
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
            console.log('[xforms-javascript-library] Adding action for event ' + name);
        }
        
        var getEventAction = function(name){
            return eventActions[name];
        }
                
        var updateAction = function(actioni, key, value){
            actioni[key] = value;
            return actioni;
        }
                
        var addSubmission = function(name, value){
            submissions[name] = value;
        }
                
        var getSubmission = function(name){
            return submissions[name];
        }     
                
        var addOutput = function(name, value){
            outputs[name] = value;
        }
                
        var getOutput = function(name){
            return outputs[name];
        }
                
        var getOutputKeys = function() {
            return Object.keys(outputs);
        }
                
        // repeats is a map of HTML IDs to (parsed) xf:repeat/@nodeset values
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
                
         var setFocus = function(id) {
            var item = document.getElementById(id);
            item.focus();
            // alert('setFocus on ' + id);
         }
         
    </xsl:variable>
</xsl:stylesheet>