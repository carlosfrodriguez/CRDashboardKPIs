// --
// Core.Agent.Admin.CRKPI.js - provides the special module functions for the KPIs.
// Copyright (C) 2001-2012 OTRS Carlos Rodríguez
// --
// Basid in OTRS file Core.Agent.Admin.DynamicField.js
// Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.Admin.KPI
 * @description
 *      This namespace contains the special module functions for the CRKPI module.
 */
Core.Agent.Admin.KPI = (function (TargetNS) {

    /**
     * @function
     * @private
     * @param {Object} Data The data that should be converted
     * @return {string} query string of the data
     * @description Converts a given hash into a query string
     */
    function SerializeData(Data) {
        var QueryString = '';
        $.each(Data, function (Key, Value) {
            QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });
        return QueryString;
    }

    TargetNS.Redirect = function( ObjectType ) {
        var KPIsConfig, Action, URL;

        // get configuration
        KPIsConfig = Core.Config.Get('KPIs');

        // get action
        Action = KPIsConfig[ ObjectType ];

        // redirect to correct url
        URL = Core.Config.Get('Baselink') + 'Action=' + Action + ';Subaction=Add';
        URL += SerializeData(Core.App.GetSessionInformation());
        window.location = URL;
    };

    return TargetNS;
}(Core.Agent.Admin.KPI || {}));
