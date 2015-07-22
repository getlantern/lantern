/*
 * Copyright (c) 2010 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

(function($)
{
    function bind(org_cometd, cookie, ReloadExtension, cometd)
    {
        // Remap cometd COOKIE functions to jquery cookie functions
        // Avoid to set to undefined if the jquery cookie plugin is not present
        if (cookie)
        {
            org_cometd.COOKIE.set = cookie;
            org_cometd.COOKIE.get = cookie;
        }

        var result = new ReloadExtension();
        cometd.registerExtension('reload', result);
        return result;
    }

    if (typeof define === 'function' && define.amd)
    {
        define(['org/cometd', 'jquery.cookie', 'org/cometd/ReloadExtension', 'jquery.cometd'], bind);
    }
    else
    {
        bind(org.cometd, $.cookie, org.cometd.ReloadExtension, $.cometd);
    }
})(jQuery);
