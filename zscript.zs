version 4.5


// Hacked DERP Bot
class HDERPBot : HDUPK {
    HDPlayerPawn driver;
    float accel;
    float max_speed;
    float turn_speed;
    double driver_angle;
    bool use_mouse;

    default {
        +Actor.ISMONSTER
        +Actor.NOBLOCKMONST
        +Actor.SHOOTABLE
        +Actor.FRIENDLY
        +Actor.NOFEAR
        +Actor.DONTGIB
        +Actor.NOBLOOD
        +Actor.GHOST
        -Actor.NOGRAVITY

        Health 100;
        Mass 20;
        Speed 0;
        DamageFactor "Thermal", 0.7;
        DamageFactor "Normal", 0.8;
        Radius 4;
        Height 8;
        DeathHeight 8;
        MaxDropOffHeight 4;
        MaxStepHeight 4;
        BloodColor "22 22 22";
        Scale 0.6;
        HDUPK.PickupSound "derp/crawl";
        HDUPK.PickupMessage ""; // Let the pickup do this
        Tag "H.D.E.R.P. robot";
    }

    override void BeginPlay() {
        max_speed = 2;
        turn_speed = 2;
        use_mouse = true;
    }

    double GetActualAngle() {
        // 361 should not be possible to achieve
        int ts = driver.angle / 360;

        // Check if negative
        if (driver.angle < 0) {
            ts = (ts < 0)? ts * -1 + 1 : 1;
            return (driver.angle + (360 * ts));
        } else {
            return (driver.angle - (360 * ts));
        }
    }

    override void Tick() {
        Super.Tick();
        float new_speed;
        if (driver) {
            // Dismount if crouch jumping
            if (
                driver.player.cmd.buttons & BT_CROUCH &&
                driver.player.cmd.buttons & BT_JUMP
            ) {
                driver.A_Log("Dismounting.", true);
                driver = null;
                return;
            }

            // Turn
            if (use_mouse) {
                driver_angle = GetActualAngle();

                //console.printf(string.format("driverangle: %f actual_angle:%f", driver.angle, driver_angle));

                if (angle != driver_angle) {
                    // Find the shorter path
                    float angle_diff = driver_angle - angle;
                    double new_angle;
                    bool is_flipped = (
                        angle_diff > 180 ||
                        (angle_diff < 0 && angle_diff > -180)
                    );
                    turn_speed = (angle_diff < 0)? log(-angle_diff) : log(angle_diff);
                    angle = (is_flipped)? angle - turn_speed : angle + turn_speed;
                }
            } else {
                if (driver.player.cmd.buttons & BT_MOVELEFT) {
                    angle += turn_speed;
                } else if (driver.player.cmd.buttons & BT_MOVERIGHT) {
                    angle -= turn_speed;
                }
            }

            if (angle > 360) {
                angle = 1;
            } else if (angle < 0) {
                angle = 359;
            }

            // Drive
            if (driver.player.cmd.buttons & BT_FORWARD) {
                // Accelerate
                new_speed += 0.1;
            } else if (driver.player.cmd.buttons & BT_BACK) {
                // Decelerate
                if (speed > 0) {
                    new_speed -= 0.2;
                } else {
                    new_speed -= 0.1;
                }
            }
            driver.SetOrigin(pos, true);
        }

        if (new_speed == 0 && speed != 0) {
            // Friction
            bool is_negative = (speed < 0);
            new_speed = (is_negative)? speed + 0.05 : speed - 0.05;
            speed = (is_negative)? min(new_speed, 0) : max(new_speed, 0);
        } else {
            speed += new_speed;
        }

        // Make sure you aren't flying at the speed of light
        speed = Clamp(speed, -max_speed, max_speed);

        Vector2 nv2 = (cos(angle), sin(angle)) * speed;
        if (floorz >= pos.z) {
            vel.x += nv2.x;
            vel.y += nv2.y;
        }

        /*
        Console.PrintF(string.Format(
            "=HDERP= Speed:%f Angle:%d vel-x:%f vel-y:%f",
            speed, angle, vel.x, vel.y
        ));
        */
    }

    override bool OnGrab(actor grabber) {
        if (!grabber) return false;

        // Grab if crouching
        if (!driver) {
            driver = HDPlayerPawn(grabber);
            driver.SetOrigin(pos, true);
        } else if (
            driver &&
            driver == HDPlayerPawn(grabber) &&
            driver.player.cmd.buttons & BT_CROUCH
        ) {
            driver.A_Log("Dismounting.", true);
            driver = null;
        }
        return false;
    }

    States {
        Give:
            DERP A 0 {
                HDPlayerPawn hdp = HDPlayerPawn(target);
                if (hdp && !driver) {
                    driver = hdp;
                    driver.SetOrigin(pos, true);
                    return;
                }
            }
            goto Spawn;
        Spawn:
            DERP A 1;
            loop;

        Death:
            DERP A -1;
            stop;
    }
}

class HDERPUiHandler : EventHandler {
    override void RenderOverlay(RenderEvent e) {
        HDPlayerPawn hdp = HDPlayerPawn(players[consoleplayer].mo);
        if (!hdp) {
            return;
        }

        let hderps = ThinkerIterator.Create("HDERPBot");
        let hderp = hderps.next();

        while (hderp) {
            let hacked = HDERPBot(hderp);
            if (hacked.driver && hacked.driver == hdp) {
                // Rotation magic
                Vector2 driver_angle = (cos(hacked.driver_angle), sin(hacked.driver_angle));
                // Get the angles
                Vector2 hderp_angle = (255 + (cos(hacked.angle - hacked.driver_angle) * 20), 255 + (sin(hacked.angle - hacked.driver_angle) * 20));

                // Draw the compass
                Screen.DrawLine(255, 255, 255 * 5, 255, "green", 255);
                Screen.DrawLine(255, 255, hderp_angle.x, hderp_angle.y, "white", 255);
            }
            hderp = hderps.next();
        }
    }
}
