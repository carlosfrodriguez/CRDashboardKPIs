// --
// Core.Agent.DashboardCRKPI.js - provides the special module functions for the KPIs.
// Copyright (C) 2001-2012 OTRS Carlos Rodríguez
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Dashboard = Core.Agent.Dashboard || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.DashboardKPI
 * @description
 *      This namespace contains the special module functions for the CRKPI module.
 */
Core.Agent.DashboardKPI = (function (TargetNS) {
    var Gages = {};

    TargetNS.RegisterKPI = function( ElementID, Data ) {

        $('#' + ElementID).empty();
        Gages.ElementID = new JustGage({
            id: ElementID,
            value: Data.Value,
            min: Data.Min,
            max: Data.Max,
            title: Data.Name,
            startAnimationTime : 2000
          });
    };

    return TargetNS;
}(Core.Agent.Dashboard.KPI || {}));
