/*
 * Copyright 2011-2021 GatlingCorp (https://gatling.io)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package fruits

import scala.concurrent.duration._
import scala.util.Random

import io.gatling.core.Predef._
import io.gatling.http.Predef._

class BasicSimulation extends Simulation {

    var name="quarkus-rest-test"
    var users=1
    var rampupTime=600 seconds
    var repeatTimes=300

    def startup() = {
       	var url="http://" + System.getenv("QHOST") + ":" + System.getenv("QPORT");
        val httpProtocol = http.baseUrl(url)

        val sim = repeat(repeatTimes, "n") {
            exec(http("get-1")
                .get("/fruits/1")
            )

            .pause(334.milliseconds)

            .exec(
                http("get-all")
              .get("/fruits")
            )
            .pause(643.milliseconds)

        }
        
        val scn = scenario(name).exec(sim)
        
        
        setUp(scn.inject(rampUsers(users).during(rampupTime))).protocols(httpProtocol)
    }
}

class Basic1user extends BasicSimulation {
    users=1
    startup()
}

class Basic10user extends BasicSimulation {
    users=10
    startup()
}

class Basic100user extends BasicSimulation {
    users=100
    startup()
}

class Basic200user extends BasicSimulation {
    users=200
    startup()
}

class Basic500user extends BasicSimulation {
    users=500
    startup()
}

class Basic1000user extends BasicSimulation {
    users=1000
    repeatTimes=240
    startup()
}

class Basic2000user extends BasicSimulation {
    users=2000
    startup()
}

class Basic5000ser extends BasicSimulation {
    users=5000
    startup()
}

