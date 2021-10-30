# Classify text extracted from ICLA

module ICLATEXT
  TEXT = Set.new

  def self.compress(str)
    str.strip.squeeze(' ')
  end

  UNDERCOUNT = 16
  UNDER = '_' * UNDERCOUNT
  UNDER_MATCH = %r{(_{#{UNDERCOUNT},})}
  def self.type(line)
    txt = compress(line)
    return :text if TEXT.include? txt
    # drop leading "*" and "(optional"
    sqz = txt.sub(%r{^\* *}, '').sub(%r{^ *\(optional\) *}, '').gsub(UNDER_MATCH, UNDER)
    return FORMS[sqz] || :other
  end

  # underlines have all been compressed to 16 char, as that was the shortest found
  # Also dropped the following prefixes: "(optional)", "*"
  FORMS = {
    "Full name: ________________" => :FullName,
    "Legal name: ________________" => :FullName,
    "Public name: ________________" => :PublicName,
    "Display name: ________________" => :PublicName,
    "Mailing Address: ________________" => :MailingAddress,
    "Postal Address: ________________" => :MailingAddress,
    "PostalAddress: ________________" => :MailingAddress,
    "Address: ________________" => :MailingAddress,
    "________________" => :MailingAddress2,
    "Country: ________________" => :Country,
    "E-Mail: ________________" => :EMail,
    "preferred Apache id(s): ________________" => :ApacheID,
    "Preferred ApacheID: ________________" => :ApacheID,
    "PreferredApacheID: ________________" => :ApacheID,
    "Alternative ApacheID(s): ________________" => :ApacheID,
    "AlternativeApacheID(s): ________________" => :ApacheID,
    "notify project: ________________" => :Project,
    "GitHub id(s): ________________" => :Github,
    "Facsimile: ________________" => :Facsimile,
    "Telephone: ________________" => :Telephone,
    "Please sign: ________________ Date: ________________" => :Date,
    "Please sign:________________ Date: ________________" => :Date,
  }

  # Tried using __END__ text but the DATA pointer relates to the calling file.
  # The first line is deliberately blank
  # The lines below have been extracted from all icla.pdf versions since r1029599,
  # compressed and deduplicated.
  TEXTS = <<'XYXYXY'

  (no cc: to
  "Contribution" shall mean any original work of authorship,
  "Contribution" shall mean any original work of authorship, including any modifications or additions to an
  "Contribution" shall mean any original work of authorship, including any modifications or additions to an existing work, that is
  "Foundation"). In order to clarify the intellectual property license
  "Submitted on behalf of a third-party: [named here]".
  "You" (or "Your") shall mean the copyright owner or legal entity
  "You" (or "Your") shall mean the copyright owner or legal entity authorized by the copyright owner that is
  "You" (or "Your") shall mean the copyright owner or legal entity authorized by the copyright owner that is making this
  "control" means (i) the power, direct or indirect, to cause the
  "submitted" means any form of electronic, verbal, or written
  "submitted" means any form of electronic, verbal, or written communication sent to the Foundation or its
  ("Agreement") V2.0
  ("Agreement") V2.1
  (50%) or more of the outstanding shares, or (iii) beneficial ownership of such entity.
  (except as stated in this section) patent license to make, have
  (except as stated in this section) patent license to make, have made, use, offer to sell, sell, import, and otherwise transfer the
  (including a cross-claim or counterclaim in a lawsuit) alleging
  * These fields will become part of your public profile.
  * if you do not enter a display name your legal name will be public
  * if you do not enter a public name your legal name will be public
  +1-919-573-9199. If necessary, send an original signed Agreement to
  1. Definitions.
  2. Grant of Copyright License. Subject to the terms and conditions of
  2. Grant of Copyright License. Subject to the terms and conditions of this Agreement, You hereby grant to the
  2. Grant of Copyright License. Subject to the terms and conditions of this Agreement, You hereby grant to the Foundation and to
  3. Grant of Patent License. Subject to the terms and conditions of
  3. Grant of Patent License. Subject to the terms and conditions of this Agreement, You hereby grant to the
  3. Grant of Patent License. Subject to the terms and conditions of thisAgreement, You hereby grant to the Foundation and to
  4. You represent that you are legally entitled to grant the above
  4. You represent that you are legally entitled to grant the above license. If your employer(s) has rights to
  4. You represent that you are legally entitled to grant the above license. If your employer(s) has rights to intellectual property that
  5. You represent that each of Your Contributions is Your original
  5. You represent that each of Your Contributions is Your original creation (see section 7 for submissions on behalf
  5. You represent that each of Your Contributions is Your original creation (see section 7 for submissions on behalf of others). You
  6. You are not expected to provide support for Your Contributions,
  6. You are not expected to provide support for Your Contributions, except to the extent You desire to provide
  6. You are not expected to provide support for Your Contributions, except to the extent You desire to provide support. You may
  7. Should You wish to submit work that is not Your original creation,
  7. Should You wish to submit work that is not Your original creation, You may submit it to the Foundation
  7. Should You wish to submit work that is not Your original creation, You may submit it to the Foundation separately from any
  8. You agree to notify the Foundation of any facts or circumstances of
  8. You agree to notify the Foundation of any facts or circumstances of which you become aware that would make
  8. You agree to notify the Foundation of any facts or circumstances of which you become aware that would make these
  90084-9660, U.S.A. Please read this document carefully before signing and keep a copy for your records.
  Agreement with the Foundation. For legal entities, the entity making a Contribution and all other entities that control, are
  Alternatively, you may send it by facsimile to the Foundation at
  CA 90084-9660, U.S.A. Please read this document carefully before
  CONDITIONS OF ANY KIND, either express or implied, including, without limitation, any warranties or
  Contribution and all other entities that control, are controlled
  Contribution(s) alone or by combination of Your Contribution(s)
  Contribution(s) alone or by combination of Your Contribution(s) with the Work to which such Contribution(s) was submitted. If
  Contribution(s) with the Work to which such Contribution(s) was submitted. If any entity institutes patent
  Contribution, identifying the complete details of its source and of
  Contribution, identifying the complete details of its source and of any license or other restriction (including, but not limited to,
  Contributions and such derivative works.
  Contributions on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
  Contributions on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
  Contributions.
  Contributor License Agreement ("CLA") on file that has been signed by each Contributor, indicating agreement to
  Foundation and its users; it does not change your rights to use your own Contributions for any other purpose.
  Foundation and to recipients of software distributed by the Foundation a perpetual, worldwide, non-exclusive,
  Foundation.
  INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE.
  If you have not already done so, please complete and sign, then email
  If you have not already done so, please complete and sign, then scan
  If you have not already done so, please complete and sign, then scan and email a pdf file of this Agreement to
  Individual Contributor
  License Agreement
  MERCHANTABILITY, or FITNESS FORAPARTICULAR PURPOSE.
  OF ANY KIND, either express or implied, including, without
  PURPOSE.
  Page 1 of 2
  Page 2 of 2
  Please complete and sign, then email a pdf file of this Agreement to
  Please read this document carefully before signing and keep a copy
  Please refer to https://s.apache.org/cla-privacy-policy for the policy
  Please refer to
  https://s.apache.org/cla-privacy-policy
  for the policy
  Thank you for your interest in The Apache Software Foundation (the
  Thank you for your interest in The Apache Software Foundation (the "Foundation"). In order to clarify the
  Thank you for your interest in TheApache Software Foundation (the "Foundation"). In order to clarify the intellectual property license
  The Apache Software Foundation Individual Contributor License Agreement V2.0
  The Apache Software Foundation, Dept. 9660, Los Angeles,
  This is a legal contract containing Personally Identifiable Information.
  Work, where such license applies only to those patent claims
  Work, where such license applies only to those patent claims licensable by You that are necessarily infringed by Your
  You accept and agree to the following terms and conditions for Your
  You accept and agree to the following terms and conditions for Your present and future Contributions submitted to
  You accept and agree to the following terms and conditions for Your present and future Contributions submitted to the Foundation. In
  You may submit it to the Foundation separately from any
  Your Contributions.
  a pdf file of this Agreement only to
  a pdf file of this Agreement only to secretary@apache.org (no cc: to
  alleging that your Contribution, or the Work to which you have contributed, constitutes direct or contributory patent
  and email a pdf file of this Agreement to secretary@apache.org.
  and interest in and to Your Contributions.
  any entity institutes patent litigation against You or any other entity (including a cross-claim or counterclaim in a lawsuit)
  any license or other restriction (including, but not limited to,
  any of the products owned or managed by the Foundation (the "Work"). For the purposes of this definition,
  any other persons or lists). Please read this document carefully
  applicable law or agreed to in writing, You provide Your
  are managed by, or on behalf of, the Foundation for the purpose of
  are personally aware and which are associated with any part of Your
  are personally aware, and conspicuously marking the work as
  as "Not a Contribution."
  as of the date such litigation is filed.
  as well as the protection of the Foundation and its users; it does not change your rights to use your own Contributions for any other
  authorized by the copyright owner that is making this Agreement
  aware and which are associated with any part of Your Contributions.
  be a single Contributor. For the purposes of this definition,
  been signed by each Contributor, indicating agreement to the license
  before signing and keep a copy for your records.
  benefit or inconsistent with its nonprofit status and bylaws in effect at the time of the Contribution. Except for the
  but not limited to, related patents and trademarks) of which you
  but not limited to, related patents and trademarks) of which you are personally aware and which are associated with any part of
  by the Foundation (the "Work"). For the purposes of this definition, "submitted" means any form of electronic, verbal, or written
  by, or are under common control with that entity are considered to
  change your rights to use your own Contributions for any other purpose.
  check this box only if names are entered with family name first
  claims licensable by You that are necessarily infringed by Your Contribution(s) alone or by combination of Your
  communication sent to the Foundation or its representatives,
  communication sent to the Foundation or its representatives, including but not limited to communication on electronic mailing
  conditions of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR APARTICULAR
  constitutes direct or contributory patent infringement, then any
  contract or otherwise, or (ii) ownership of fifty percent (50%) or more of the outstanding shares, or (iii) beneficial ownership of
  controlled by, or are under common control with that entity are considered to be a single Contributor. For the purposes of this
  copyright license to reproduce, prepare derivative works of,
  copyright license to reproduce, prepare derivative works of, publicly display, publicly perform, sublicense, and distribute Your
  creation (see section 7 for submissions on behalf of others). You
  definition, "control" means (i) the power, direct or indirect, to cause the direction or management of such entity, whether by
  designated in writing by You as "Not a Contribution."
  details of any third-party license or other restriction (including,
  direction or management of such entity, whether by contract or
  discussing and improving the Work, but excluding communication that
  discussing and improving the Work, but excluding communication that is conspicuously marked or otherwise
  display, publicly perform, sublicense, and distribute Your Contributions and such derivative works.
  only (do not copy any other persons or lists).
  entities that control, are controlled by, or are under common control with that entity are considered to be a
  entity institutes patent litigation against You or any other entity
  except to the extent You desire to provide support. You may provide
  executed a separate Corporate CLA with the Foundation.
  executed a separate Corporate CLAwith the Foundation.
  existing work, that is intentionally submitted by You to the Foundation for inclusion in, or documentation of,
  for the license granted herein to the Foundation and recipients of
  for your records.
  governing how this information is used and shared.
  granted with Contributions from any person or entity, the Foundation
  granted with Contributions from any person or entity, the Foundation must have a Contributor License Agreement ("CLA") on file that
  has been signed by each Contributor, indicating agreement to the license terms below. This license is for your protection as a Contributor
  http://www.apache.org/licenses/
  implied, including, without limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT,
  in writing, You provide Your Contributions on an "AS IS" BASIS, WITHOUT WARRANTIES OR
  in, or documentation of, any of the products owned or managed by
  inaccurate in any respect.
  including any modifications or additions to an existing work, that
  including but not limited to communication on electronic mailing
  infringement, then any patent licenses granted to that entity under this Agreement for that Contribution or Work
  infringement, then any patent licenses granted to that entity under this Agreement for that Contribution or Work shall terminate
  intellectual property license granted with Contributions from any person or entity, the Foundation must have a
  intellectual property that you create that includes your Contributions, you represent that you have received
  intentionally submitted by You to the Foundation for inclusion in, or documentation of, any of the products owned or managed
  is conspicuously marked or otherwise designated in writing by You
  is contrary to the public benefit or inconsistent with its nonprofit
  is intentionally submitted by You to the Foundation for inclusion
  legal and public names are entered with family name first
  licensable by You that are necessarily infringed by Your
  license granted herein to the Foundation and recipients of software distributed by the Foundation, You reserve all
  license. If your employer(s) has rights to intellectual property
  limitation, any warranties or conditions of TITLE, NON-
  lists, source code control systems, and issue tracking systems that
  lists, source code control systems, and issue tracking systems that are managed by, or on behalf of, the Foundation for the
  litigation against You or any other entity (including a cross-claim or counterclaim in a lawsuit) alleging that
  litigation is filed.
  made, use, offer to sell, sell, import, and otherwise transfer the
  making this Agreement with the Foundation. For legal entities, the entity making a Contribution and all other
  must have a Contributor License Agreement ("CLA") on file that has
  necessary, send an original signed Agreement to The Apache Software Foundation, Dept. 9660, Los Angeles, CA
  no-charge, royalty-free, irrevocable (except as stated in this section) patent license to make, have made, use,
  no-charge, royalty-free, irrevocable copyright license to reproduce, prepare derivative works of, publicly
  of others). You represent that Your Contribution submissions include complete details of any third-party license
  of that employer, that your employer has waived such rights for
  offer to sell, sell, import, and otherwise transfer the Work, where such license applies only to those patent
  or other restriction (including, but not limited to, related patents and trademarks) of which you are personally
  otherwise, or (ii) ownership of fifty percent (50%) or more of the
  outstanding shares, or (iii) beneficial ownership of such entity.
  patent licenses granted to that entity under this Agreement for
  permission to make Contributions on behalf of that employer, that your employer has waived such rights for
  personally aware, and conspicuously marking the work as "Submitted on behalf of a third-party: [named here]".
  present and future Contributions submitted to the Foundation. In
  provide support for free, for a fee, or not at all. Unless required by applicable law or agreed to in writing, You provide Your
  publicly display, publicly perform, sublicense, and distribute Your
  purpose of discussing and improving the Work, but excluding communication that is conspicuously marked or otherwise
  purpose. If you have not already done so, please complete and sign, then scan and email a pdf file of this Agreement to
  recipients of software distributed by the Foundation a perpetual,
  recipients of software distributed by the Foundation a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable
  related patents, trademarks, and license agreements) of which you
  related patents, trademarks, and license agreements) of which you are personally aware, and conspicuously marking the work as
  represent that Your Contribution submissions include complete
  represent that Your Contribution submissions include complete details of any third-party license or other restriction (including,
  representations inaccurate in any respect.
  representatives, including but not limited to communication on electronic mailing lists, source code control
  restriction (including, but not limited to, related patents, trademarks, and license agreements) of which you are
  return, the Foundation shall not use Your Contributions in a way that
  return, the Foundation shall not use Your Contributions in a way that is contrary to the public benefit or inconsistent with its nonprofit
  right, title, and interest in and to Your Contributions.
  secretary@apache.org
  secretary@apache.org only (do not copy any other persons or lists).
  secretary@apache.org. Alternatively, you may send it by facsimile to the Foundation at +1-919-573-9199. If
  secretary@apache.org. Please read this document carefully before signing and keep a copy for your records.
  separately from any Contribution, identifying the complete details of its source and of any license or other
  shall terminate as of the date such litigation is filed.
  signing and keep a copy for your records.
  single Contributor. For the purposes of this definition, "control" means (i) the power, direct or indirect, to cause
  software distributed by the Foundation, You reserve all right, title,
  software distributed by the Foundation, You reserve all right, title, and interest in and to Your Contributions.
  status and bylaws in effect at the time of the Contribution. Except
  status and bylaws in effect at the time of the Contribution. Except for the license granted herein to the Foundation and recipients of
  such entity.
  support for free, for a fee, or not at all. Unless required by
  support. You may provide support for free, for a fee, or not at all. Unless required by applicable law or agreed to
  systems, and issue tracking systems that are managed by, or on behalf of, the Foundation for the purpose of
  terms below. This license is for your protection as a Contributor as
  that Contribution or Work shall terminate as of the date such
  that employer, that your employer has waived such rights for your Contributions to the Foundation, or that your employer has
  that you create that includes your Contributions, you represent
  that you have received permission to make Contributions on behalf
  that your Contribution, or the Work to which you have contributed,
  the Foundation (the "Work"). For the purposes of this definition,
  the Foundation. In return, the Foundation shall not use Your Contributions in a way that is contrary to the public
  the direction or management of such entity, whether by contract or otherwise, or (ii) ownership of fifty percent
  the license terms below. This license is for your protection as a Contributor as well as the protection of the
  these representations inaccurate in any respect.
  this Agreement, You hereby grant to the Foundation and to
  well as the protection of the Foundation and its users; it does not
  which you become aware that would make these representations
  with the Foundation. For legal entities, the entity making a
  with the Work to which such Contribution(s) was submitted. If any
  worldwide, non-exclusive, no-charge, royalty-free, irrevocable
  you create that includes your Contributions, you represent that you have received permission to make Contributions on behalf of
  your Contribution, or the Work to which you have contributed, constitutes direct or contributory patent
  your Contributions to the Foundation, or that your employer has
  your Contributions to the Foundation, or that your employer has executed a separate Corporate CLAwith the
XYXYXY

  TEXTS.each_line do |line|
    TEXT.add compress line
  end
  # puts "Loaded #{SKIP.size} lines"
end
