p4 = bfrt.mon.pipe

#fwd_table = p4.SwitchIngress.fwd


#fwd_table.add_with_send(ctrl=2, port=160)


register_low = p4.SwitchEgress.byte_count.reg_lo
register_low_carry = p4.SwitchEgress.byte_count.reg_lo_carry
register_hi = p4.SwitchEgress.byte_count.reg_hi


register_low.get(from_hw=True, REGISTER_INDEX=134)

register_low_carry.get(from_hw=True, REGISTER_INDEX=134)

register_hi.get(from_hw=True, REGISTER_INDEX=134)


bfrt.complete_operations()


