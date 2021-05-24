version 4.5


// Hacked DERP Bot
class HDERPBot : HDUPK {
    HDPlayerPawn driver;
    int battery; // 0-20
    float accel;
    float max_speed;
    float break_speed;
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
        break_speed = 1;
        turn_speed = 2;
        use_mouse = true;
        battery = 20;
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

    void HijackMove() {
        if (driver) {
            driver.movehijacked = true;
        } else {
            driver.player.cmd.forwardmove = 0;
            driver.player.cmd.sidemove = 0;
        }
    }

    void DoTurn() {
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
            turn_speed = 2;
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
    }

    override void Tick() {
        Super.Tick();
        float new_speed;
        if (driver) {
            // Can't ride a vehicle if you're down
            if (driver.incapacitated || health == 0) {
                driver = null;
                return;
            }

            // Dismount if crouch jumping
            if (
                driver.player.cmd.buttons & BT_CROUCH &&
                driver.player.cmd.buttons & BT_JUMP
            ) {
                driver.A_Log("Dismounting.", true);
                driver = null;
                return;
            }

            // Moved into its own function, because it was getting messy
            DoTurn();

            // Drive
            bool use_battery;
            if (driver.player.cmd.buttons & BT_FORWARD) {
                // Accelerate
                new_speed += 0.1;
                use_battery = true;
            } else if (driver.player.cmd.buttons & BT_BACK) {
                // Decelerate
                if (speed > 0) {
                    new_speed -= 0.2;
                } else {
                    new_speed -= 0.1;
                }
                use_battery = true;
            }
            driver.SetOrigin(pos, true);
            if (use_battery && battery > 0 && !random(0,4096)) battery--;
        }

        if (new_speed == 0 && speed != 0) {
            // Friction
            bool is_negative = (speed < 0);
            new_speed = (is_negative)? speed + 0.025 : speed - 0.025;
            speed = (is_negative)? min(new_speed, 0) : max(new_speed, 0);
        } else {
            speed += new_speed;
        }

        // Make sure you aren't flying at the speed of light
        speed = Clamp(speed, -break_speed, max_speed);

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
            !driver &&
            grabber.player.cmd.buttons & BT_CROUCH
        ) {
            return true;
        }
        return false;
    }

    States {
        Spawn:
            DERP A 1;
            loop;

        Death:
            DERP A -1;
            stop;
    }
}

class HDERPUsable : HDWeapon {
    default {
        +Weapon.WIMPY_WEAPON
        +Inventory.INVBAR
        +HDWeapon.DROPTRANSLATION
        +HDWeapon.FITSINBACKPACK
        HDWeapon.barrelsize 0, 0, 0;
        Weapon.SelectionOrder 1014;

        Scale 0.6;
        Inventory.Icon "DERPEX";
        Inventory.PickupMessage "Picked up a... Wait, what did you do to this D.E.R.P???";
        Inventory.PickupSound "derp/crawl";
        Translation 0;
        Tag "H.D.E.R.P. robot";
    }

    override string GetHelpText() {
        return 
            ((weaponstatus[0]&DERPF_BROKEN)?
            (WEPHELP_FIRE.."+"..WEPHELP_RELOAD.."  Repair\n") : (WEPHELP_FIRE.."  Deploy\n"))
            ..WEPHELP_RELOAD.."  Reload battery\n"
            ..WEPHELP_UNLOAD.."  Unload battery"
            ;
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
